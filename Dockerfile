FROM gitlab-registry.mpcdf.mpg.de/nomad-lab/nomad-fair:develop

RUN pip install --no-cache-dir --upgrade pip

COPY plugins/ plugins/

RUN pip install ./plugins/nomad-measurements