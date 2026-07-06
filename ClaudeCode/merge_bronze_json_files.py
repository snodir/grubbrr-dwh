# function_app.py
import azure.functions as func
import asyncio
import logging
import json
import os
from azure.storage.filedatalake.aio import DataLakeServiceClient
from azure.core.exceptions import ResourceExistsError

app = func.FunctionApp()

CONN_STR = "DefaultEndpointsProtocol=https;AccountName=stg_acct_name;AccountKey=acct_key=;EndpointSuffix=core.windows.net"
CONTAINER = "bronze"                      # single container — raw and compacted both live here
FILES_PER_MERGED_OUTPUT = 10            # tune — e.g. 250K files / 5000 = ~50 output files
MAX_CONCURRENT_READS = 75                 # tune based on observed throttling behavior


def get_compacted_path(hour_folder: str) -> str:
    """
    Converts 'orders/raw/2026/06/09/08' -> 'orders/compacted/2026/06/09/08'
    Assumes 'raw' appears exactly once as a path segment.
    """
    parts = hour_folder.split("/")
    if "raw" not in parts:
        raise ValueError(f"Expected 'raw' segment in hour_folder: {hour_folder}")
    parts[parts.index("raw")] = "compacted"
    return "/".join(parts)


async def download_file(fs_client, file_path: str) -> str:
    file_client = fs_client.get_file_client(file_path)
    stream = await file_client.download_file()
    content = await stream.readall()
    return content.decode("utf-8").strip()


async def download_batch(fs_client, file_paths: list, semaphore: asyncio.Semaphore) -> list:
    async def bounded_download(path):
        async with semaphore:
            try:
                return await download_file(fs_client, path)
            except Exception as e:
                logging.warning(f"Failed to read {path}: {e}")
                return None  # skip failed file rather than fail whole batch

    results = await asyncio.gather(*[bounded_download(p) for p in file_paths])
    return [r for r in results if r is not None]


async def write_merged_file(fs_client, compacted_folder: str, batch_id: int, lines: list) -> str:
    merged_content = "\n".join(lines)
    out_path = f"{compacted_folder}/merged_{batch_id:04d}.json"
    file_client = fs_client.get_file_client(out_path)
    await file_client.upload_data(merged_content.encode("utf-8"), overwrite=True)
    return out_path


async def compact_hour_folder(hour_folder: str) -> dict:
    compacted_folder = get_compacted_path(hour_folder)

    async with DataLakeServiceClient.from_connection_string(CONN_STR) as service_client:
        fs_client = service_client.get_file_system_client(CONTAINER)

        # list all files under the raw hour-folder path
        paths = fs_client.get_paths(path=hour_folder)
        file_list = [p.name async for p in paths if not p.is_directory]

        if not file_list:
            return {
                "hour_folder": hour_folder,
                "status": "no_files_found",
                "output_files": []
            }

        total_files = len(file_list)
        semaphore = asyncio.Semaphore(MAX_CONCURRENT_READS)

        batches = [
            file_list[i:i + FILES_PER_MERGED_OUTPUT]
            for i in range(0, total_files, FILES_PER_MERGED_OUTPUT)
        ]

        output_files = []
        failed_count = 0

        for batch_id, batch in enumerate(batches):
            lines = await download_batch(fs_client, batch, semaphore)
            failed_count += len(batch) - len(lines)
            if lines:
                out_path = await write_merged_file(fs_client, compacted_folder, batch_id, lines)
                output_files.append(out_path)

        return {
            "hour_folder": hour_folder,
            "compacted_folder": compacted_folder,
            "status": "completed",
            "total_source_files": total_files,
            "output_file_count": len(output_files),
            "output_files": output_files,
            "failed_file_count": failed_count
        }


@app.route(route="compact", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
async def compact_files(req: func.HttpRequest) -> func.HttpResponse:
    try:
        req_body = req.get_json()
        hour_folder = req_body.get("hour_folder")  # e.g. "orders/raw/2026/06/09/08"

        if not hour_folder:
            return func.HttpResponse("Missing 'hour_folder' in request body", status_code=400)

        result = await compact_hour_folder(hour_folder)
        return func.HttpResponse(json.dumps(result), mimetype="application/json", status_code=200)

    except Exception as e:
        logging.exception("Compaction failed")
        return func.HttpResponse(json.dumps({"error": str(e)}), mimetype="application/json", status_code=500)