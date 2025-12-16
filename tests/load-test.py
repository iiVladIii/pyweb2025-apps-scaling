import requests
import time
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed

URLS = ["http://localhost:30080/api/counter", "http://localhost/api/counter"]
API_URL = None

NUM_REQUESTS = 50000
NUM_THREADS = 50

def find_api_url():
    global API_URL
    for url in URLS:
        try:
            r = requests.get(url, timeout=2)
            if r.status_code == 200:
                API_URL = url
                return True
        except:
            continue
    return False

def make_request(action='increment'):
    start = time.time()
    try:
        if action == 'get':
            r = requests.get(API_URL, timeout=5)
        else:
            r = requests.post(f"{API_URL}/{action}", timeout=5)
        duration = time.time() - start
        return {'success': r.status_code == 200, 'duration': duration}
    except Exception as e:
        return {'success': False, 'duration': time.time() - start, 'error': str(e)}

def run_load_test():
    if not find_api_url():
        print("❌ Cannot connect to API. Tried:")
        for url in URLS:
            print(f"   - {url}")
        return

    print(f"Starting load test: {NUM_REQUESTS} requests, {NUM_THREADS} threads")
    print(f"Target: {API_URL}\n")

    results = []
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=NUM_THREADS) as executor:
        futures = [executor.submit(make_request, 'increment' if i % 2 == 0 else 'get')
                   for i in range(NUM_REQUESTS)]

        for future in as_completed(futures):
            results.append(future.result())

    total_time = time.time() - start_time
    successful = [r for r in results if r['success']]
    failed = [r for r in results if not r['success']]
    durations = [r['duration'] for r in successful]

    print(f"=== Results ===")
    print(f"Total time: {total_time:.2f}s")
    print(f"Total requests: {len(results)}")
    print(f"Successful: {len(successful)}")
    print(f"Failed: {len(failed)}")
    if len(successful) > 0:
        print(f"Requests per second: {len(successful) / total_time:.2f}")

    if durations:
        print(f"\n=== Response Times ===")
        print(f"Min: {min(durations)*1000:.2f}ms")
        print(f"Max: {max(durations)*1000:.2f}ms")
        print(f"Average: {statistics.mean(durations)*1000:.2f}ms")
        print(f"Median: {statistics.median(durations)*1000:.2f}ms")
        if len(durations) > 1:
            print(f"StdDev: {statistics.stdev(durations)*1000:.2f}ms")

if __name__ == "__main__":
    run_load_test()
