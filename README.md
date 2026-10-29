[![GC Start](gcp_banner.png)](https://cloud.google.com/?utm_source=github&utm_medium=referral&utm_campaign=GCP&utm_content=packages_repository_banner)
# Host a Serverless Wordpress Site with Cloud Run

## Introduction

_This architecture uses click-to-deploy so you can spin up infrastructure in minutes using terraform!_

43% of the Web is built on Wordpress. Because of its simplicity and versatility, Wordpress can be used for internal websites and customer facing e-commerce platforms in small to large businesses, while still offering security. **Cloud Run automatically scales your WordPress application to handle any amount of traffic**, without requiring manual intervention. This means that your website can handle large traffic spikes, without worrying about capacity.

Cloud Run allows you to deploy your WordPress application quickly and easily, with a few clicks or commands. You can deploy your application from a container image stored in a container registry or directly from a Git repository. This click-to-deploy architecture leverages the serverless and scalability benefits of using Cloud Run to host a Wordpress Application connected to a MySQL instance.

This repo is based on the Cloud Foundation Fabric blueprint available [here](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/master/blueprints/third-party-solutions/wordpress/cloudrun).

## Use cases

These are some of the use cases you can build on top of this infrastructure:
* Business websites
* E-commerce websites
* Portfolios
* Non-profit websites
* Educational Websites

## Architecture

![Wordpress on Cloud Run](architecture.png "Wordpress on Cloud Run")

The main components that are deployed in this architecture are the following (you can learn about them by following the hyperlinks):

* [Cloud Run](https://cloud.google.com/run): serverless PaaS offering to host containers for web-oriented applications, while offering security, scalability and easy versioning
* [Cloud SQL](https://cloud.google.com/sql): Managed solution for SQL databases
* [VPC Serverless Connector](https://cloud.google.com/vpc/docs/serverless-vpc-access): Solution to access the CloudSQL VPC from Cloud Run, using only internal IP addresses

## Costs

Pricing Estimates - We have created a sample estimate based on some usage we see from new startups looking to scale. This estimate would give you an idea of how much this deployment would essentially cost per month at this scale and you extend it to the scale you further prefer. Here's the [link](https://cloud.google.com/products/calculator#id=8a7471c9-98df-4b71-97de-6222d22484c8).


## Setting up the project for the deployment

This example will deploy all its resources into the project defined by the `project_id` variable. Please note that we assume this project already exists. However, if you provide the appropriate values to the `project_create` variable, the project will be created as part of the deployment.

If `project_create` is set to null, the identity performing the deployment needs the `owner` role on the project defined by the `project_id` variable. Otherwise, the identity performing the deployment needs `resourcemanager.projectCreator` on the resource hierarchy node specified by `project_create.parent` and `billing.user` on the billing account specified by `project_create.billing_account_id`.

## Deploy the architecture

Before we deploy the architecture, you will need the following information:

* The __service project ID__.
* A __unique prefix__ that you want all the deployed resources to have (for example: awesomestartup). This must be a string with no spaces or tabs.
* A __Wordpress image__ if you want to use your own, otherwise you can use the provided standard image.
* A __list of Groups or Users__ with Service Account Token creator role on Service Accounts in IAM format, eg 'group:group@domain.com'.

**Notes**:

1. If you want to change your admin password later on, please note that you can only do so via the Wordpress user interface.
2. If you have the [domain restriction org. policy](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains) on your organization, you have to edit the `cloud_run_invoker` variable and give it a value that will be accepted in accordance to your policy.

Click on the button below, sign in if required and when the prompt appears, click on “confirm”. It will walk you through setting up your architecture.

[![Open Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2FGoogleCloudPlatform%2Fdeploystack-wordpress-on-cloudrun&cloudshell_image=gcr.io%2Fds-artifacts-cloudshell%2Fdeploystack_custom_image&cloudshell_git_branch=main&cloudshell_tutorial=tutorial.md)


This is the startup screen that appears after clicking the button and confirming:

![cloud_shell](cloud_shell.png)

During the process, you will be asked for some user input. All necessary variables are explained at the bottom of this ReadMe file. In case of failure, you can simply click the button again.

<center>
<h4>🎉 Congratulations! 🎉  <br />
You have successfully deployed the foundation for running Wordpress using CloudRun on Google Cloud.</h4></center>


**Note**: 
You might get the following error (or a similar one):

``` {shell}
│ Error: resource is in failed state "Ready:False", message: Revision '...' is not ready and cannot serve traffic.│
```

In case this happens, manually run
``` {shell}
    deploystack install
```
to run the installation again.

## Using the Wordpress Installation

Upon completion, you will see the output with the values for the Cloud Run service and the user and password to access the `/admin` part of the website. You can also view it later with:

``` {shell}
terraform output
# or for the concrete variable:
terraform output cloud_run_service
```

When clicking on the Wordpress link, it will immediately prompt you to register as an administrator. The password will be pre-filled and can be changed after registration. 

## Customizing & Operating WordPress on Cloud Run

Because Cloud Run containers are stateless and use an ephemeral filesystem, local filesystem changes made at runtime (such as media uploads or plugins/themes installed through the WordPress Admin UI) do not persist across container restarts or scale-out events. Below is how to configure persistent storage, custom plugins/themes, and WordPress version updates.

### 1. Persistent Media Storage with Cloud Storage

You have two options to persist media uploads (`/var/www/html/wp-content/uploads`) in a Google Cloud Storage (GCS) bucket:

#### Option A: Cloud Run Gen2 Cloud Storage Volume Mount (Terraform)

Cloud Run (2nd generation execution environment) supports mounting a Cloud Storage bucket directly into the container via Cloud Storage FUSE. Add a GCS bucket module and mount it into `module "cloud_run"` in `main.tf`:

```hcl
module "uploads_bucket" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=v59.2.0"
  project_id = module.project.project_id
  prefix     = var.prefix
  name       = "wp-uploads"
  location   = var.region
}
```

Then in `module "cloud_run"` (`main.tf`), add the `uploads` volume, mount it to `/var/www/html/wp-content/uploads`, and enable the Gen2 execution environment:

```hcl
  containers = {
    wordpress = {
      # ... existing image, ports, env ...
      volume_mounts = {
        "cloudsql" = "/cloudsql"
        "uploads"  = "/var/www/html/wp-content/uploads"
      }
    }
  }

  volumes = {
    "cloudsql" = {
      cloud_sql_instances = [module.cloudsql.connection_name]
    }
    "uploads" = {
      gcs = {
        bucket       = module.uploads_bucket.name
        is_read_only = false
      }
    }
  }

  service_config = {
    gen2_execution_environment = true
    ingress                    = "INGRESS_TRAFFIC_ALL"
    scaling = {
      min_instance_count = 1
      max_instance_count = 2
    }
  }
```

#### Option B: WP-Stateless Plugin

Alternatively, bake the [WP-Stateless](https://wordpress.org/plugins/wp-stateless/) plugin into your container image to offload media uploads directly to a Cloud Storage bucket via the GCS API without using a FUSE mount.

### 2. Adding Custom Themes and Plugins

To ensure themes and plugins persist across container scaling and revisions, package them into a custom container image stored in [Artifact Registry](https://cloud.google.com/artifact-registry):

1. Create a `Dockerfile` that extends the official WordPress image and copies or installs your themes and plugins:

```dockerfile
FROM mirror.gcr.io/library/wordpress:6.7-php8.3-apache

# Copy custom themes or plugins from your repository
COPY ./themes/my-theme /var/www/html/wp-content/themes/my-theme
COPY ./plugins/my-plugin /var/www/html/wp-content/plugins/my-plugin

# Or download plugins directly from WordPress.org during build
RUN apt-get update && apt-get install -y --no-install-recommends unzip curl \
    && curl -sL https://downloads.wordpress.org/plugin/wp-stateless.latest-stable.zip -o /tmp/wp-stateless.zip \
    && unzip -q /tmp/wp-stateless.zip -d /var/www/html/wp-content/plugins/ \
    && rm -f /tmp/wp-stateless.zip \
    && chown -R www-data:www-data /var/www/html/wp-content \
    && rm -rf /var/lib/apt/lists/*
```

2. Build and push the image to Artifact Registry using Cloud Build:

``` {shell}
gcloud artifacts repositories create wordpress-repo \
  --repository-format=docker \
  --location=europe-west1

gcloud builds submit \
  --tag europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/wordpress-repo/wordpress:v1
```

3. Pass your custom image URI via the `wordpress_image` variable when deploying (`wordpress_image = "europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/wordpress-repo/wordpress:v1"`).

### 3. Managing WordPress Updates

* **How `mirror.gcr.io/library/wordpress` works**: By default, this stack uses `mirror.gcr.io/library/wordpress`, which is Google Cloud's pull-through cache of the official [Docker Hub `wordpress` image](https://hub.docker.com/_/wordpress) maintained by the WordPress Docker community.
* **Updating WordPress safely**: Because Cloud Run containers are immutable, do not run core or plugin updates from the WordPress Admin dashboard in production (those changes only affect a single ephemeral container instance). Instead:
  1. Pin a specific version tag in your `Dockerfile` or `wordpress_image` variable (for example, `mirror.gcr.io/library/wordpress:6.7.2-php8.3-apache`).
  2. When a new WordPress version is released, rebuild/re-tag your image (or bump the `wordpress_image` tag) and run `terraform apply` (or `gcloud run services update`) to roll out a new Cloud Run revision with zero downtime.

## Cleaning Up Your Environment

The easiest way to remove all deployed resources is to run the following command in Cloud Shell:

``` {shell}
deploystack uninstall
```

The above command will delete the associated resources so there will be no billable charges made afterwards.

## Standalone deployment

Since the scripts are based on Terraform (`>= 1.12.2`), it is possible to deploy this solution through `Terraform` directly, without having to go through `Deploystack`. (When using `deploystack install`, `.deploystack/scripts/preinit.sh` automatically upgrades Terraform if the Cloud Shell image has an older version installed; for standalone deployments in Cloud Shell, run `tfswitch 1.12.2` or `. .deploystack/scripts/preinit.sh` first.)

Just clone this repo, create a `terraform.tfvars` file with your own values and call the following commands:
``` {shell}
terraform init
terraform plan -out=execplan.out
terraform apply execplan.out
```

## Special Thanks
A special thank you goes out to Natalia Strelkova (skalolazka) and Grigory Movsesyan, the original developers of this example architecture.

<!-- BEGIN TFDOC -->

## Variables

| name | description | type | default |
|---|---|:---:|:---:|
| [project_id](variables.tf#L78) | Project id, references existing project if `project_create` is null. | <code>string</code> | |
| [cloud_run_invoker](variables.tf#L18) | IAM member authorized to access the end-point (for example, 'user:YOUR_IAM_USER' for only you or 'allUsers' for everyone) | <code>string</code> | <code>&#34;allUsers&#34;</code> |
| [cloudsql_password](variables.tf#L24) | CloudSQL password (will be randomly generated by default) | <code>string</code> | <code>null</code> |
| [connector](variables.tf#L30) | Existing VPC serverless connector to use if not creating a new one | <code>string</code> | <code>null</code> |
| [create_connector](variables.tf#L36) | Should a VPC serverless connector be created or not | <code>bool</code> | <code>true</code> |
| [ip_ranges](variables.tf#L43) | CIDR blocks: VPC serverless connector, Private Service Access(PSA) for CloudSQL, CloudSQL VPC | <code title="object&#40;&#123;&#10;  connector &#61; string&#10;  psa       &#61; string&#10;  sql_vpc   &#61; string&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> | <code title="&#123;&#10;  connector &#61; &#34;10.8.0.0&#47;28&#34;&#10;  psa       &#61; &#34;10.60.0.0&#47;24&#34;&#10;  sql_vpc   &#61; &#34;10.0.0.0&#47;20&#34;&#10;&#125;">&#123;&#8230;&#125;</code> |
| [prefix](variables.tf#L57) | Unique prefix used for resource names. Not used for project if 'project_create' is null. | <code>string</code> | <code>&#34;&#34;</code> |
| [principals](variables.tf#L63) | List of users to give rights to (CloudSQL admin, client and instanceUser, Logging admin, Service Account User and TokenCreator), eg 'user@domain.com'. | <code>list&#40;string&#41;</code> | <code>&#91;&#93;</code> |
| [project_create](variables.tf#L69) | Provide values if project creation is needed, uses existing project if null. Parent is in 'folders/nnn' or 'organizations/nnn' format. | <code title="object&#40;&#123;&#10;  billing_account_id &#61; string&#10;  parent             &#61; string&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> | <code>null</code> |
| [region](variables.tf#L83) | The region where resources will be deployed. | <code>string</code> | <code>&#34;europe-west1&#34;</code> |
| [wordpress_image](variables.tf#L89) | Image to run with Cloud Run, starts with \"gcr.io\" or \"REGION-docker.pkg.dev\" | <code>string</code> | <code>&#34;mirror.gcr.io/library/wordpress&#34;</code> |
| [wordpress_port](variables.tf#L95) | Port for the Wordpress image | <code>number</code> | <code>80</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [cloud_run_service](outputs.tf#L17) | CloudRun service URL | |
| [cloudsql_password](outputs.tf#L22) | CloudSQL password | ✓ |

<!-- END TFDOC -->
