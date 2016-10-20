# k8s-digitalocean-coreos
This repo contains a few [Terraform](https://www.terraform.io/) modules that
should let you spin up a production-ready Kubernetes cluster on DigitalOcean.

## Requirements
* terraform
* A DigitalOcean API key with write access (directions
  [here](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2))
* A DigitalOcean API key with read-only access (used for
  [DropLan](https://github.com/tam7t/droplan))

## Getting Started

Once you have your API keys handy, it's just a matter of setting up the shared
configuration that the modules use.

To prevent repeated requests for DO access token set your digital ocean api key
as an environment variable:
```
export DIGITALOCEAN_ACCESS_TOKEN="INSERT_TOKEN_HERE"
export DIGITALOCEAN_TOKEN=$DIGITALOCEAN_ACCESS_TOKEN
```
(We recommend using [direnv](https://github.com/direnv/direnv) and an .envrc file to make this easier.)

### `config.tfvars`
Copy the `config.tfvars.template` file to `config.tfvars`. Set the value of the
`do_read_token` variable to a read-only DigitalOcean token for your account.

Next, you'll need to get an etcd discovery token

```
curl -w "\n" 'https://discovery.etcd.io/new?size=3'
# Should return something like: https://discovery.etcd.io/6a28e078895c5ec737174db2419bb2f3
```

Set the value of the `discovery_url` variable to the URL given back by the
discovery API. This will let your etcd cluster quickly bootstrap by using the
token.

### `secrets.tfvars`
You will also need to provide a DigitalOcean API token with write access to
your account along with a ssh key id or fingerprint that has been added to your
account.

You should create a `secrets.tfvars` file with the following content replacing the values as necessary:

```
ssh_keys = "YOUR_SSH_KEYS"
do_token = "DO_API_WRITE_TOKEN"
```
## Get the terraform modules
```
terraform get
```

## Create your etcd cluster
```
terraform plan -var-file config.tfvars -var-file secrets.tfvars --target module.etcd
```

## Create your Kubernetes cluster

```
terraform plan -var-file config.tfvars -var-file secrets.tfvars
```
