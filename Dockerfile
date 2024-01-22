FROM gitlab-registry.mpcdf.mpg.de/nomad-lab/nomad-fair:develop

RUN pip install xmltodict

COPY --chown=nomad:1000 ./plugins/nomad-measurements/src/nomad_measurements /app/plugins/nomad_measurements
COPY --chown=nomad:1000 ./plugins/nomad-measurements/src/nomad_measurements/xrd /app/plugins/xrd
