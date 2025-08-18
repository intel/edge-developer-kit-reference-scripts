# AI Video Analytics
A sample application to perform semantic search and face identification with embedding search on uploaded video.

## Example
![Alt Text](./assets/example.gif)

## Validated Hardware
* CPU: Intel® Core™ Ultra 7 processors
* RAM: 16GB
* DISK: 128GB

## Prerequisite
### 1. Install the operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.


### Application Ports
Please ensure that you have these ports available before running the applications.

| Apps     | Port |
|----------|------|
| Server   | 5980 |

## Quick Start
### Prerequisite
Docker and docker compose should be setup before running the commands below. Refer to [here](https://docs.docker.com/engine/install/) to setup docker.

### 1. Build Docker Container
```
docker compose build
```

### 2. Start Docker Container
```
docker compose up -d
```
### 3. Access the App
Navigate to http://localhost:5980
