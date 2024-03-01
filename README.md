# DTU Nanolab's NOMAD Oasis Image
A repository for composing and hosting the NOMAD oasis image for DTU Nanolab.

## Adding or updating a plugin

To add a new plugin to the docker image you should add it to the [plugins.txt](plugins.txt) file.

Here you can put either plugins distributed to PyPI, e.g.
```
nomad-material-processing
```
or plugins in a git repository with either the commit hash
```
git+https://github.com/FAIRmat-NFDI/nomad-measurements.git@71b7e8c9bb376ce9e8610aba9a20be0b5bce6775
```
or with a tag
```
git+https://github.com/FAIRmat-NFDI/nomad-measurements.git@v0.0.4
```
To add a plugin in a subdirectory of a git repository you can use the `subdirectory` option, e.g.
```
git+https://github.com/FAIRmat-NFDI/AreaA-data_modeling_and_schemas.git@30fc90843428d1b36a1d222874803abae8b1cb42#subdirectory=PVD/PLD/jeremy_ikz/ikz_pld_plugin
```

If the plugin is new, you also need to add it under `plugins` in the [nomad.yaml](nomad.yaml)
config file that will be included in the image.
For example, if you have added a schema plugin `nomad_material_processing` you should add 
the following:

```yaml
plugins:
  options:
    schemas/nomad_material_processing:
      python_package: nomad_material_processing
```

Once the changes have been committed to the main branch, the new image will automatically be generated.

## Try out this Oasis

- Find a linux computer.
- Make sure you have [docker](https://docs.docker.com/engine/install/) installed.
Docker nowadays comes with `docker compose` build in. Prior, you needed to
install the stand alone [docker-compose](https://docs.docker.com/compose/install/).
- Download the modified configuration files [nomad-oasis.zip](nomad-oasis_files/nomad-oasis.zip?raw=1) from this repository.
- Run the following commands (skip `chown` on MacOS and Windows computers)


```sh
unzip nomad-oasis.zip
cd nomad-oasis
sudo chown -R 1000 .volumes
docker compose pull
docker compose up -d
curl localhost/nomad-oasis/alive
```

- Open [http://localhost/nomad-oasis](http://localhost/nomad-oasis) in your browser.

To run NORTH (the NOMAD Remote Tools Hub), the `hub` container needs to run docker and
the container has to be run under the docker group. You need to replace the default group
id `991` in the `docker-compose.yaml`'s `hub` section with your systems docker group id.
Run `id` if you are a docker user, or `getent group | grep docker` to find our your
systems docker gid. The user id 1000 is used as the nomad user inside all containers.
