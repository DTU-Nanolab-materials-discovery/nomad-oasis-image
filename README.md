![docker image](https://github.com/DTU-Nanolab-materials-discovery/nomad-oasis-image/actions/workflows/docker-publish.yml/badge.svg)


# DTU-Nanolab-materials-discovery's NOMAD Oasis Distribution

This is the NOMAD Oasis distribution of DTU-Nanolab-materials-discovery.
Below are instructions for how to [deploy this distribution](#deploying-the-distribution)
and how to customize it through [adding plugins](#adding-a-plugin).

> [!IMPORTANT]
> Depending on the settings of the owner of this repository, the distributed image might
> be private and require authentication to pull.
> If you want to keep the image private you need to configure and use a personal access
> token (PAT) according to the instructions in the GitHub docs [here](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic).
> If you want to make the image public (recommended), you should make sure that your
> organization settings allow public packages and make this package public after building it.
> You can read more about this in the GitHub docs [here](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility).

> [!TIP]
> In order for others to find and learn from your distribution we in FAIRmat would
> greatly appreciate it if you would add the topic `nomad-distribution` by clicking the
> ⚙️ next to "About" on the main GitHub page for this repository.

In this README you will find instructions for:
1. [Deploying the distribution](#deploying-the-distribution)
2. [Adding a plugin](#adding-a-plugin)
3. [Using the jupyter image](#the-jupyter-image)
4. [Automated unit and example upload tests in CI](#automated-unit-and-example-upload-tests-in-ci)
5. [Setup regular package updates with Dependabot](#set-up-regular-package-updates-with-dependabot)
6. [Updating the distribution from the template](#updating-the-distribution-from-the-template)
7. [Solving common issues](#faqtrouble-shooting)

## Deploying the distribution

Below are instructions for how to deploy this NOMAD Oasis distribution
[for a new Oasis](#for-a-new-oasis) and [for an existing Oasis](#for-an-existing-oasis)

### For a new Oasis

1. Make sure you have [docker](https://docs.docker.com/engine/install/) installed.
   Docker nowadays comes with `docker compose` built in. Prior, you needed to
   install the stand-alone [docker-compose](https://docs.docker.com/compose/install/).

2. Clone the repository or download the repository as a zip file.

    ```sh
    git clone https://github.com/DTU-Nanolab-materials-discovery/nomad-oasis-image.git
    cd nomad-oasis-image
    ```

    or

    ```sh
    curl-L -o nomad-oasis-image.zip "https://github.com/DTU-Nanolab-materials-discovery/nomad-oasis-image/archive/main.zip"
    unzip nomad-oasis-image.zip
    cd nomad-oasis-image
    ```

3. Create `.volumes` directories

    Since we are using a symlink for the file system on the production server the directory structure in the `.volumes` directory cannot be version controlled.

    The following directories need to be created for running the oasis

    ```
    .volumes
    ├── fs
    │   ├── north
    │   │   └── users
    │   ├── public
    │   ├── staging
    │   └── tmp
    └── mongo
    ```

    There is a bash script for doing this on Linux:
    ```sh
    source ./scripts/create-volumes.sh
    ```

4. _On Linux only,_ recursively change the owner of the `.volumes` directory to the nomad user (1000)

    ```sh
    sudo chown -R 1000 .volumes
    ```

5. Pull the images specified in the `docker-compose.yaml`

    Note that the image needs to be public or you need to provide a PAT (see "Important" note above).

    ```sh
    docker compose pull
    ```

6. And run it with docker compose in detached (--detach or -d) mode

    ```sh
    docker compose up -d
    ```

7. Optionally you can now test that NOMAD is running with

    ```
    curl localhost/nomad-oasis/alive
    ```

8. Finally, open [http://localhost/nomad-oasis](http://localhost/nomad-oasis) in your browser to start using your new NOMAD Oasis.

#### Updating the image
1. Whenever you update your image you need to shut down NOMAD using

    ```sh
    docker compose down
    ```

    and then repeat steps 4. and 5. above.
   
2. You can remove unused images to free up space by running

    ```sh
    docker image prune -a
    ```

#### NOMAD Remote Tools Hub (NORTH)

To run NORTH (the NOMAD Remote Tools Hub), the `hub` container needs to run docker and
the container has to be run under the docker group. You need to replace the default group
id `991` in the `docker-compose.yaml`'s `hub` section with your systems docker group id.
Run `id` if you are a docker user, or `getent group | grep docker` to find your
systems docker gid. The user id 1000 is used as the nomad user inside all containers.

Please see the [Jupyter image](#the-jupyter-image) section below for more information on the jupyter NORTH image being generated in this repository.

You can find more details on setting up and maintaining an Oasis in the NOMAD docs here:
[nomad-lab.eu/prod/v1/docs/oasis/install.html](https://nomad-lab.eu/prod/v1/docs/oasis/install.html)

### For an existing Oasis

If you already have an Oasis running you only need to change the image being pulled in
your `docker-compose.yaml` with `ghcr.io/dtu-nanolab-materials-discovery/nomad-oasis-image:main` for the services
`worker`, `app`, `north`, and `logtransfer`.

If you want to use the `nomad.yaml` from this repository you also need to comment out
the inclusion of the `nomad.yaml` under the volumes key of those services in the
`docker-compose.yaml`.

```yaml
volumes:
  # - ./configs/nomad.yaml:/app/nomad.yaml
```

To run the new image you can follow steps 5. and 6. [above](#for-a-new-oasis).

## Adding a plugin

To add a new plugin to the docker image you should add it to the plugins table in the [`pyproject.toml`](pyproject.toml) file.

Here you can put either plugins distributed to PyPI, e.g.

```toml
[project.optional-dependencies]
plugins = [
  "nomad-material-processing>=1.0.0",
]
```

or plugins in a git repository with either the commit hash

```toml
[project.optional-dependencies]
plugins = [
  "nomad-measurements @ git+https://github.com/FAIRmat-NFDI/nomad-measurements.git@71b7e8c9bb376ce9e8610aba9a20be0b5bce6775",
]
```

or with a tag

```toml
[project.optional-dependencies]
plugins = [
  "nomad-measurements @ git+https://github.com/FAIRmat-NFDI/nomad-measurements.git@v0.0.4"
]
```

To add a plugin in a subdirectory of a git repository you can use the `subdirectory` option, e.g.

```toml
[project.optional-dependencies]
plugins = [
  "ikz_pld_plugin @ git+https://github.com/FAIRmat-NFDI/AreaA-data_modeling_and_schemas.git@30fc90843428d1b36a1d222874803abae8b1cb42#subdirectory=PVD/PLD/jeremy_ikz/ikz_pld_plugin"
]
```

Once the changes have been committed to the main branch, the new image will automatically
be generated.

## The Jupyter image

In addition to the Docker image for running the oasis, this repository also builds a custom NORTH image for running a jupyter hub with the installed plugins.
This image has been added to the [`configs/nomad.yaml`](configs/nomad.yaml) during the initialization of this repository and should therefore already be available in your Oasis under "Analyze / NOMAD Remote Tools Hub / jupyter"

The image is quite large and might cause a timeout the first time it is run. In order to avoid this you can pre pull the image with:

```
docker pull ghcr.io/dtu-nanolab-materials-discovery/nomad-oasis-image/jupyter:main
```

If you want additional python packages to be available to all users in the jupyter hub you can add those to the jupyter table in the [`pyproject.toml`](pyproject.toml):

```toml
[project.optional-dependencies]
jupyter = [
  "voila",
  "ipyaggrid",
  "ipysheet",
  "ipydatagrid",
  "jupyter-flex",
]
```

## Automated Unit and Example Upload Tests in CI

By default, all unit tests from every plugin are executed to ensure system stability and catch potential issues early. These tests validate core functionality and help maintain consistency across different plugins.

In addition to unit tests, the pipeline also verifies that all example uploads can be processed correctly. This ensures that any generated entries do not contain error messages, providing confidence that data flows through the system as expected.

For example upload tests, the CI uses the image built in the Build Image step. It then runs the Docker container and starts up the application to confirm that it functions correctly. This approach ensures that if the pipeline passes, the app is more likely to run smoothly in a Dockerized environment on a server, not just locally.

If you need to disable tests for specific plugins, update the **PLUGIN_TESTS_PLUGINS_TO_SKIP** variable in [.github/workflows/docker-publish.yml](./.github/workflows/docker-publish.yml#L19) by adding the plugin names to the existing list.

## Set Up Regular Package Updates with Dependabot

Dependabot is already configured in the repository’s CI setup, but you need to enable it manually in the repository settings.

To enable Dependabot, go to Settings > Code security and analysis in your GitHub repository. From there, turn on Dependabot alerts and version updates. Once enabled, Dependabot will automatically check for dependency updates and create pull requests when new versions are available.

This automated process helps ensure that your dependencies stay up to date, improving security and reducing the risk of vulnerabilities.

## Updating the distribution from the template

In order to update an existing distribution with any potential changes in the template you can add a new `git remote` for the template and merge with that one while allowing for unrelated histories:

```
git remote add template https://github.com/FAIRmat-NFDI/nomad-distro-template
git fetch template
git merge template/main --allow-unrelated-histories
```

Most likely this will result in some merge conflicts which will need to be resolved. At the very least the `Dockerfile` and GitHub workflows should be taken from "theirs":

```
git checkout --theirs Dockerfile
git checkout --theirs .github/workflows/docker-publish.yml
```

For detailed instructions on how to resolve the merge conflicts between different version we refer you to the latest template release [notes](https://github.com/FAIRmat-NFDI/nomad-distro-template/releases/latest)

Once the merge conflicts are resolved you should add the changes and commit them

```
git add -A
git commit -m "Updated to new distribution version"
```

Ideally all workflows should be triggered automatically but you might need to run the initialization one manually by navigating to the "Actions" tab at the top, clicking "Template Repository Initialization" on the left side, and triggering it by clicking "Run workflow" under the "Run workflow" button on the right.

## FAQ/Trouble shooting

_I get an_ `Error response from daemon: Head "https://ghcr.io/v2/DTU-Nanolab-materials-discovery/nomad-oasis-image/manifests/main": unauthorized`
_when trying to pull my docker image._

Most likely you have not made the package public or provided a personal access token (PAT).
You can read how to make your package public in the GitHub docs [here](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)
or how to configure a PAT (if you want to keep the distribution private) in the GitHub
docs [here](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic).
