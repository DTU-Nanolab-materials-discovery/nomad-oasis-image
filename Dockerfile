FROM gitlab-registry.mpcdf.mpg.de/nomad-lab/nomad-fair:develop

COPY --chown=nomad:1000 ./plugins/nomad-measurements/src/nomad_measurements /app/plugins/nomad_measurements
