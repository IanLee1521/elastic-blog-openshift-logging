# Elastic Blog - Collecting OpenShift container logs using Red Hat’s OpenShift Logging Operator - Code Snippets

This repository contain the code snippets for the blog: 
[Collecting OpenShift container logs using Red Hat’s OpenShift Logging Operator](https://www.elastic.co/blog/openshift-container-logs-red-hat-logging-operator) to public discussion
and continue maintaining the pipelines.


### Setup

To upload the pipelines and create the indices we can use the 
[upload.sh](./upload.sh) script:

```
ES_URL=https://xxxxxx:9200 ES_USERNAME=myuser ES_PASSWORD=mypassword ./upload.sh
```