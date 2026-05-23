# Lab 50 — Deploy to EC2 from GitHub Actions (Complete Walkthrough)

This lab extends Lab 49. The pipeline still lints, tests, builds, and pushes to
ECR — then it **deploys the image onto an EC2 instance** over SSH and runs it as
a Docker container on port 80.

**Deploy method:** GitHub Actions SSHes into the instance, the instance pulls the
image from ECR using its own IAM instance role, and the container is restarted.
No AWS credentials are passed over SSH.

---

## Architecture

```
GitHub Actions runner                         EC2 instance (Amazon Linux 2023)
─────────────────────                         ────────────────────────────────
ci_checks (lint, test)
build_and_push ──push image──► Amazon ECR ◄──pull image── instance IAM role
deploy_to_ec2  ──SSH key────────────────────► docker run -p 80:3000 lab50-app
```

Two separate identities do two separate things:
- **GitHub OIDC role** — lets the Actions runner PUSH to ECR (from Lab 49).
- **EC2 instance role** — lets the instance PULL from ECR.

---

## Prerequisites

- [ ] Lab 49 completed (ECR + GitHub OIDC role already exist), OR you'll create
      a fresh ECR repo below
- [ ] AWS account access, region `us-east-1`
- [ ] A GitHub repo for this project
- [ ] An SSH key pair you can use for the EC2 instance

> This lab uses ECR repo `lab50/app`. If you'd rather reuse `lab49/app`, change
> the `ECR_REPO` value in `.github/workflows/ci-cd.yml` and the IAM policy
> resource ARNs accordingly.

---

## Part 1 — Create the GitHub repository and push the code

1. github.com → **+** → **New repository** → name it `lab50-ec2-deploy`,
   leave it uninitialized, **Create repository**.
2. Unzip this project, then in Git Bash:

   ```bash
   cd /c/Users/<you>/path/to/lab50-ec2-deploy
   npm install            # generates package-lock.json (needed by npm ci)
   git init
   git add .
   git commit -m "Initial commit: Lab 50 EC2 deploy pipeline"
   git branch -M main
   git remote add origin https://github.com/<your-username>/lab50-ec2-deploy.git
   git push -u origin main
   ```

The first workflow run will fail at `build_and_push` / `deploy_to_ec2` until the
AWS pieces below are in place. That's expected.

---

## Part 2 — Create the ECR repository (AWS Console)

1. Console → confirm region **us-east-1** → search **ECR** → open it.
2. **Repositories** → **Private** → **Create repository**.
3. Name: `lab50/app`, tag immutability **Enabled**, encryption AES-256.
4. **Create repository**.

(If you already set up registry-level scan-on-push in Lab 49, it covers this
repo too when the filter is `*`.)

---

## Part 3 — GitHub OIDC push role (AWS Console)

If you completed Lab 49, you already have the OIDC provider. You only need a
role/policy that can push to `lab50/app`.

1. **IAM → Policies → Create policy → JSON**, paste (replace `<ACCOUNT_ID>`):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "ECRAuth",
         "Effect": "Allow",
         "Action": "ecr:GetAuthorizationToken",
         "Resource": "*"
       },
       {
         "Sid": "ECRPush",
         "Effect": "Allow",
         "Action": [
           "ecr:BatchCheckLayerAvailability",
           "ecr:InitiateLayerUpload",
           "ecr:UploadLayerPart",
           "ecr:CompleteLayerUpload",
           "ecr:PutImage",
           "ecr:BatchGetImage"
         ],
         "Resource": "arn:aws:ecr:us-east-1:<ACCOUNT_ID>:repository/lab50/app"
       }
     ]
   }
   ```

   Name it `GitHubActions-Lab50-ECR-Policy` → **Create policy**.

2. **IAM → Roles → Create role → Web identity**, identity provider
   `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`, your
   GitHub org/username, repo `lab50-ec2-deploy`, branch `main` → **Next**.
3. Attach `GitHubActions-Lab50-ECR-Policy` → name the role
   `GitHubActions-Lab50-ECR` → **Create role**.
4. Open the role → **Trust relationships → Edit** → confirm the `sub` condition
   reads `repo:<GITHUB_USERNAME>/lab50-ec2-deploy:ref:refs/heads/main`.
5. Copy the role ARN.

---

## Part 4 — Create an IAM role for the EC2 instance to PULL from ECR

1. **IAM → Policies → Create policy → JSON**, paste (replace `<ACCOUNT_ID>`):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "ECRAuth",
         "Effect": "Allow",
         "Action": "ecr:GetAuthorizationToken",
         "Resource": "*"
       },
       {
         "Sid": "ECRPull",
         "Effect": "Allow",
         "Action": [
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:BatchGetImage"
         ],
         "Resource": "arn:aws:ecr:us-east-1:<ACCOUNT_ID>:repository/lab50/app"
       }
     ]
   }
   ```

   Name it `EC2-Lab50-ECR-Pull-Policy` → **Create policy**.

2. **IAM → Roles → Create role → AWS service → EC2** → **Next**.
3. Attach `EC2-Lab50-ECR-Pull-Policy` → name the role `EC2-Lab50-Role` →
   **Create role**.

This role gets attached to the instance in the next step. The `aws ecr
get-login-password` call in the deploy script works because of this role — no
keys on the box.

---

## Part 5 — Launch the EC2 instance (AWS Console)

1. Console → **EC2 → Instances → Launch instances**.
2. **Name:** `lab50-app-server`
3. **AMI:** Amazon Linux 2023 (free-tier eligible).
4. **Instance type:** `t3.micro` is fine for this tiny app.
5. **Key pair:** select an existing key pair, or **Create new key pair**
   (type RSA, format `.pem`). Download and keep the `.pem` file — you'll paste
   its contents into a GitHub secret.
6. **Network settings → Edit:**
   - Auto-assign public IP: **Enable**
   - Create a security group with inbound rules:
     - **SSH (22)** from **My IP** (so GitHub's runners… see note below)
     - **HTTP (80)** from **Anywhere (0.0.0.0/0)**
7. **Advanced details:**
   - **IAM instance profile:** select `EC2-Lab50-Role`
   - **User data:** paste the contents of `ec2/user-data.sh` from this project
     (installs and starts Docker).

     ⚠️ **Before pasting:** open `ec2/user-data.sh` in a plain-text editor and
     confirm nothing got auto-hyperlinked (no `[text](http://...)` Markdown).
     Auto-linking breaks the script.

8. **Launch instance.**
9. Once it's running, note the **Public IPv4 address** (or public DNS).

> **SSH source range note:** GitHub-hosted runners use a wide, changing set of
> IPs, so "My IP" will block them. For a lab, the simplest working option is to
> open SSH (22) to `0.0.0.0/0` temporarily. For anything beyond a lab, prefer
> the SSM Run Command approach (no inbound SSH at all) — ask and I'll build that
> variant.

---

## Part 6 — Add the GitHub secrets (GitHub UI)

Repo → **Settings → Secrets and variables → Actions → New repository secret**.
Add all four:

| Name           | Value                                                              |
| -------------- | ------------------------------------------------------------------ |
| `AWS_ROLE_ARN` | the `GitHubActions-Lab50-ECR` role ARN from Part 3                 |
| `EC2_HOST`     | the instance's public IPv4 address or public DNS                   |
| `EC2_USER`     | `ec2-user`                                                         |
| `EC2_SSH_KEY`  | the **entire** contents of your `.pem` file (see below)            |

To get the PEM contents in Git Bash:

```bash
cat /c/Users/<you>/Downloads/your-key.pem
```

Copy everything including the
`-----BEGIN ... PRIVATE KEY-----` and `-----END ... PRIVATE KEY-----` lines,
and paste it as the `EC2_SSH_KEY` value.

---

## Part 7 — Run the pipeline

1. Make any commit to `main` (or **Actions → re-run** the latest run).
2. Watch the three jobs in order: `ci_checks` → `build_and_push` →
   `deploy_to_ec2`.
3. The deploy job logs will show the image being pulled and the container
   starting, ending with `Deploy of <sha> succeeded`.

---

## Part 8 — Verify the deployment

1. In a browser, go to `http://<EC2_PUBLIC_IP>/` → you should see the greeting
   JSON.
2. `http://<EC2_PUBLIC_IP>/health` → `{"status":"ok"}`.
3. `http://<EC2_PUBLIC_IP>/version` → shows the short SHA you just deployed.

Or from Git Bash:

```bash
curl http://<EC2_PUBLIC_IP>/health
curl http://<EC2_PUBLIC_IP>/version
```

To confirm on the box itself:

```bash
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
sudo docker ps           # lab50-app should be running, 0.0.0.0:80->3000
sudo docker logs lab50-app
```

---

## Common problems

### `deploy_to_ec2` fails: `ssh: handshake failed` / connection timeout

- Security group isn't allowing SSH from the runner. Temporarily open port 22 to
  `0.0.0.0/0` (lab only).
- `EC2_HOST` is wrong, or the instance restarted and got a new public IP. Public
  IPs change on stop/start unless you attach an Elastic IP.

### `permission denied (publickey)`

- `EC2_USER` should be `ec2-user` for Amazon Linux (not `ubuntu` or `root`).
- `EC2_SSH_KEY` must be the full PEM including header/footer lines.

### `docker: command not found` on the instance

- User-data didn't run or Docker didn't install. SSH in and run
  `cat /var/log/cloud-init-output.log` to see the bootstrap output. Re-run the
  install commands manually if needed.

### `denied: ... not authorized to perform: ecr:GetAuthorizationToken`

- The instance role `EC2-Lab50-Role` isn't attached, or its policy is missing
  `ecr:GetAuthorizationToken` on `*`. Check **EC2 → instance → Actions →
  Security → Modify IAM role**.

### `Cannot connect to the Docker daemon`

- Docker service isn't running. SSH in: `sudo systemctl status docker`, then
  `sudo systemctl enable --now docker`.

### App not reachable in the browser

- Port 80 inbound isn't open in the security group, or the container mapped a
  different port. `sudo docker ps` should show `0.0.0.0:80->3000/tcp`.

---

## What's next

- **Add an Elastic IP** so `EC2_HOST` stays stable across restarts.
- **Zero-downtime deploys** — run the new container on a temp port, health-check
  it, then swap (or put NGINX / an ALB in front).
- **Switch to SSM Run Command** to eliminate the inbound SSH port entirely.
- **Auto Scaling Group + ALB** — move from a single instance to a fleet, the way
  Lab 10 did for Strapi.
