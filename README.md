# Employee Attrition MLOps Platform

An end-to-end MLOps project for training, serving, and operationalizing an employee attrition prediction model.

This repository includes:
- A local data-prep and model-training workflow
- A FastAPI inference service with a Flask frontend
- Kubernetes manifests for deployment
- An Airflow + DVC setup for automated dataset versioning

## Note On Project Origin

This project was adapted from a publicly available MLOps learning repository and then customized for my own GitHub portfolio, deployment flow, and documentation. If you publish it, keep that attribution honest instead of presenting the whole codebase as fully original work.

## Project Goals

- Build a repeatable ML pipeline from raw dataset to trained artifact
- Expose the model through an API and simple web UI
- Package the serving layer for Kubernetes
- Automate dataset versioning and Git-based updates with Airflow and DVC

## Repository Layout

```text
phase-1-local-dev/
  datasets/                  Sample dataset used by the pipeline
  src/
    data_preparation/        Ingestion, validation, cleaning, feature engineering
    model_training/          Training, evaluation, tuning, cross-validation
    model_testing/           Local prediction script
    config/                  Shared path configuration
  frontend/                  Flask UI for submitting prediction requests
  inference/                 FastAPI inference service
  k8s/                       KServe and frontend deployment manifests

phase-2-enterprise-setup/
  airflow/dags/              Airflow DAG for DVC-based dataset automation

platform-tools/
  airflow/                   Airflow image and Helm-related files
  aks/                       Azure AKS and Blob Storage helper script
```

## Architecture

1. Raw employee attrition data is stored in `phase-1-local-dev/datasets/employee_attrition.csv`.
2. Data preparation scripts transform the dataset into train/test artifacts.
3. Training scripts create `artifacts/model.pkl`.
4. The FastAPI service loads the trained model and exposes `/predict`.
5. The Flask frontend sends user input to the inference API.
6. Kubernetes manifests package the UI and model-serving layer for deployment.
7. In the enterprise path, Airflow clones the repo, pulls DVC data, updates the dataset, then pushes the new version to Git and Azure Blob Storage.

## Local Quick Start

### 1. Train the model locally

Create a Python environment and install base dependencies:

```bash
cd phase-1-local-dev
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Run the pipeline stages in sequence:

```bash
cd src
python data_preparation/01_ingestion.py
python data_preparation/02_validation.py
python data_preparation/03_eda.py
python data_preparation/04_cleaning.py
python data_preparation/05_feature_engg.py
python data_preparation/06_preprocessing.py
python model_training/01_training.py
python model_training/02_evaluation.py
python model_training/03_cross_validation.py
python model_training/04_tuning.py
```

Expected output:
- Processed files under `phase-1-local-dev/datasets/processed/`
- Trained artifact under `phase-1-local-dev/artifacts/model.pkl`

### 2. Run the inference API

In a new terminal:

```bash
cd phase-1-local-dev/inference
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn src.app:app --host 0.0.0.0 --port 8080
```

Health checks:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

### 3. Run the frontend

In another terminal:

```bash
cd phase-1-local-dev/frontend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export MODEL_ENDPOINT=http://localhost:8080/predict
python app.py
```

Open the UI at:

`http://localhost:5000`

## Kubernetes Deployment

The repo includes:
- [phase-1-local-dev/k8s/deployment.yaml](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-1-local-dev/k8s/deployment.yaml)
- [phase-1-local-dev/k8s/inference.yaml](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-1-local-dev/k8s/inference.yaml)

Before using them in your own GitHub/project setup, update:
- Docker image names from `techiescamp/...` to your own Docker Hub or container registry images
- Any namespace, service, or hostname conventions you want to standardize
- The frontend `MODEL_ENDPOINT` if your inference service name changes
- The Airflow Git sync repo URL in `platform-tools/airflow/helm/custom-values.yaml`

## Config And Secrets

### Local run

No mandatory secrets are required for the basic local workflow.

Optional local config:
- `MODEL_ENDPOINT`
  - Used by the Flask frontend
  - Default: `http://localhost:8080/predict`

### Enterprise Airflow + DVC setup

The Airflow DAG at [phase-2-enterprise-setup/airflow/dags/dataset-pipeline.py](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-2-enterprise-setup/airflow/dags/dataset-pipeline.py) expects the following:

- `GIT_SYNC_USERNAME`
  - Git username used for cloning/pushing the repo from Airflow
- `GIT_SYNC_PASSWORD`
  - Git access token or GitHub personal access token
- `GIT_REPO`
  - Repository URL to clone
  - The DAG currently hardcodes `https://github.com/techiescamp/mlops-for-devops-dev.git`, so change this to your own repo before using it
- `GIT_BRANCH`
  - Branch Airflow should pull from and push back to
- `DVC_DATA_FILE`
  - Dataset path tracked by DVC
- `SHARED_DIR`
  - Shared path used inside the Airflow worker pods
- `RUN_DATE`
  - Provided by the DAG for commit messages

Kubernetes secret expected by the DAG:

```bash
kubectl create secret generic git-credentials \
  --from-literal=GIT_SYNC_USERNAME=your-github-username \
  --from-literal=GIT_SYNC_PASSWORD=your-github-token \
  -n airflow
```

### Azure / AKS / Blob Storage requirements

The helper script at [platform-tools/aks/script.sh](/Users/ronaksolanki/Downloads/mlops-for-devops-main/platform-tools/aks/script.sh) assumes:

- An Azure account
- Azure CLI configured locally
- `kubectl` access to your AKS cluster
- An Azure Storage account and blob container for DVC storage
- Permission to create resource group storage resources, namespace resources, and Kubernetes secrets

Values you will likely want to change in that script:
- `RESOURCE_GROUP`
- `LOCATION`
- `AKS_CLUSTER_NAME`
- `STORAGE_ACCOUNT_NAME`
- `STORAGE_CONTAINER_NAME`

## What To Change Before Pushing To Your GitHub

At minimum, update these project-owned values so the repo points to your infrastructure:

1. Replace the Git repo URL in [phase-2-enterprise-setup/airflow/dags/dataset-pipeline.py](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-2-enterprise-setup/airflow/dags/dataset-pipeline.py) with your repository URL.
2. Replace the Airflow Git sync repo in [platform-tools/airflow/helm/custom-values.yaml](/Users/ronaksolanki/Downloads/mlops-for-devops-main/platform-tools/airflow/helm/custom-values.yaml) with your repository URL and secret reference if needed.
3. Replace the Docker image names in [phase-1-local-dev/k8s/deployment.yaml](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-1-local-dev/k8s/deployment.yaml) and [phase-1-local-dev/k8s/inference.yaml](/Users/ronaksolanki/Downloads/mlops-for-devops-main/phase-1-local-dev/k8s/inference.yaml) with images you build and publish.
4. Review the Azure values in [platform-tools/aks/script.sh](/Users/ronaksolanki/Downloads/mlops-for-devops-main/platform-tools/aks/script.sh) and set them to your subscription, cluster, and storage naming.
5. Add your own screenshots, architecture notes, deployment results, or experiments if you want the repository to reflect your work more clearly.

## Suggested Next Improvements

If you want this repo to feel more like your own engineering project, the strongest changes are:
- Add a proper `.env.example`
- Add Makefile targets for training, serving, and local startup
- Add CI for linting and image builds
- Add a short architecture diagram
- Add model evaluation outputs and sample API requests
- Add your own deployment notes for AKS or another platform

## License

Review the existing license files before republishing:
- [LICENSE](/Users/ronaksolanki/Downloads/mlops-for-devops-main/LICENSE)
- [licenses/LICENSE-CODE](/Users/ronaksolanki/Downloads/mlops-for-devops-main/licenses/LICENSE-CODE)
- [licenses/LICENSE-CONTENT](/Users/ronaksolanki/Downloads/mlops-for-devops-main/licenses/LICENSE-CONTENT)

Make sure your reuse complies with the original licensing terms, especially for documentation and content.
