# Gitlab CI/CD pipeline with aws integration for magento 2 deployment

# Contents Overview
1. [Project sequence diagram](#1-project-sequence-diagram)
2. [Pre-Requistices](#2-pre-requistics)
3. [Configure repository](#3-configure-repository)
4. [Configure gitlab server](#4-configure-gitlab-server)
5. [Configure golden server](#5-configure-golden-server)
6. [Configure cron server](#6-configure-cron-server)

# 1. Project sequence diagram
![Deployment Pipeline](deployment-pipeline.png)

# 2. Pre-Requistics
- Magento 2 existing project installed and running on staging/production ec2 manually
- All services endpoint accessible from staging/production ec2 server
- Proper credentals/vpn to ssh into staging/production ec2 servers
- Gitlab installed and running
- Magento repository configured in gitlab
- Proper credentals to ssh into gitlab hosted server
- Two gitlab shell runner configured

# 3. Configure repository
- Clone this repository in your pc
- Follow steps below and configure repository for [existing](#-existing-magento-repository) and [cloud](#repository-for-cloud)

## Existing magento repository
- Add the config samples to your existing magento repository, replace `$path_to_your_project` with your project path
```
cp .gitlab-ci.yml.dis $path_to_your_project/.gitlab-ci.yml
cp .gitignore.dis $path_to_your_project/.gitignore
cp .rsyncignore.dis $path_to_your_project/.rsyncignore
cp -r .ec2.dis $path_to_your_project/.ec2
```
- Modify `.gitignore` file as needed
- `.ec2/shared` has config samples which will be shared between staging/production, modify as needed
- The php logs path has been modified to `/var/log/php/php*.log`, recommended to do similar in your server php fpm config
- `.ec2/production` has config samples for production only, replace `$domain_name` with your domain name in file names and file contents
- Replace all `$variable` in `.ec2/production/magento/env.php` file with production services information
- `.ec2/staging` has config samples for staging only, replace `$domain_name` with your domain name in file names and file contents
- Replace all `$variable` in `.ec2/staging/magento/env.php` file with staging services information
- By default `.gitlab-ci.yml` file does not have job for staging `deploy to cron`, duplicate from production if needed
- Commit changes and push to your existing magento respository

## Repository for cloud
- Create a new repository preferably with `cloud` suffix to your existing repository name, example `company-magento-cloud`
- Delete default `master` branch and create two new branches as `staging` and `production`
- Clone your existing magento repository into these two new branches
- Keep `production` branch as default/protected, `staging` branch can be left unprotected to allow force pushes
- Restrict the two gitlab runner created to this project and add `production` in tags to one and `staging` in tags to another
- Configure production gitlab runner to only run on pipelines triggered on protected branches for security

# 4. Configure gitlab server

# 5. Configure golden server

# 6. Configure cron server