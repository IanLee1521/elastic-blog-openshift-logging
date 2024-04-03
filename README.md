# Elastic Blog - Collecting OpenShift container logs using Red Hat’s OpenShift Logging Operator - Code Snippets

This repository contain the code snippets for the blog: 
[Collecting OpenShift container logs using Red Hat’s OpenShift Logging Operator](https://www.elastic.co/blog/openshift-container-logs-red-hat-logging-operator) to public discussion
and continue maintaining the pipelines.


### Setup

To upload the pipelines and create the indices we can use the 
[bootstrap.sh](./bootstrap.sh) script:

```
ES_URL=https://xxxxxx:9200 ES_USERNAME=myuser ES_PASSWORD=mypassword ./bootstrap.sh
```

The script is based on the `yq` command to convert YAML files to JSON.
You can follow the [`yq` installation instrunctions](https://github.com/mikefarah/yq?tab=readme-ov-file#install) or install the `yq` python package.