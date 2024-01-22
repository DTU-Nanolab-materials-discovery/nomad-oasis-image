FROM gitlab-registry.mpcdf.mpg.de/nomad-lab/nomad-fair:develop

RUN pip install --no-cache-dir --upgrade pip

COPY --chown=nomad:1000 ./plugins/nomad-measurements /app/plugins/nomad_measurements
WORKDIR /app
RUN pip install ./plugins/nomad-measurements