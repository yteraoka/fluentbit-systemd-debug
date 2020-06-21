import datetime
import json
import os
import signal
import sys
import time

StopFlag = False

def stop_handler(signum, _):
    global StopFlag
    StopFlag = True

if __name__ == '__main__':
    sleep_sec = os.environ.get('SLEEP_SEC')
    if sleep_sec is None:
        sleep_sec = 1
    else:
        sleep_sec = float(sleep_sec)

    signal.signal(signal.SIGINT, stop_handler)
    signal.signal(signal.SIGTERM, stop_handler)

    i = 0
    while True:
        if StopFlag:
            print("{} {}".format(datetime.datetime.now().isoformat(), 0), flush=True)
            sys.exit(0)
        else:
            print("{} {}".format(datetime.datetime.now().isoformat(), i), flush=True)

        time.sleep(sleep_sec)
        i += 1
