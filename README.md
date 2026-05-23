# lab50-ec2-deploy

Lab 50 — extends the Lab 49 pipeline to **deploy the container to an EC2
instance** after pushing the image to Amazon ECR.

```



push to main
   ↓
ci_checks      → lint + unit tests
   ↓
build_and_push → build image, push to ECR (short SHA + latest) via OIDC
   ↓
deploy_to_ec2  → SSH into EC2, pull image from ECR, restart container on :80
```

## Endpoints

| Method | Path       | Response                                     |
| ------ | ---------- | -------------------------------------------- |
| GET    | `/`        | `{ "message": "Hello from Lab 50", ... }`    |
| GET    | `/health`  | `{ "status": "ok" }`                         |
| GET    | `/version` | `{ "version": "<sha>", "commit": "<sha>" }`  |

## Local development

```bash
npm install
npm run lint
npm test
npm start          # http://localhost:3000/health
```

## Required GitHub secrets

| Name           | Value                                                          |
| -------------- | -------------------------------------------------------------- |
| `AWS_ROLE_ARN` | IAM role ARN assumed by Actions to push to ECR (OIDC)          |
| `EC2_HOST`     | Public IP or DNS of the EC2 instance                           |
| `EC2_USER`     | SSH user (`ec2-user` on Amazon Linux)                          |
| `EC2_SSH_KEY`  | Private key (full PEM contents) matching the instance key pair |

See `INSTRUCTIONS.md` for the complete console-by-console setup.
