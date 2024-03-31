#!/usr/bin/python3

import requests
import sys
def GetMetrics(url):
    response = requests.get('{0}/api/v1/label/__name__/values'.format(url))
    names = response.json()['data']
    return names


if len(sys.argv) != 3:
    print('Usage: {0} http://<prometheus_URL> [1h]/[1d] period'.format(sys.argv[0]))
    sys.exit(1)

metrics = [i for i in GetMetrics(sys.argv[1]) if i.startswith("node_") or i.startswith("tpcc_") or i.startswith("mysql_")]

for metric in metrics:
     response = requests.get('{0}/api/v1/query'.format(sys.argv[1]),
     params={'query': metric+sys.argv[2]})
     results = response.json()['data']['result']
     with open(f"{metric}.json", "w") as f:
         f.write(str(results))
