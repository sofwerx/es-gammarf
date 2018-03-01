# es-gammarf

This is a dockerized gammarf submitting data directly to elasticsearch, that also works with a containerized gpsd, while also managing to NOT require running with `--net=host` (`network_mode: host`).

There is a small patch to gammarf to allow `DNS_HOST` and `DNS_PORT` which is tracked in the sofwerx gammarf fork.
