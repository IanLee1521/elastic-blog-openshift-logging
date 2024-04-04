# Collecting OpenShift container logs using Red Hat’s OpenShift Logging Operator


This blog explores a possible approach to collecting and formatting OpenShift
Container Platform logs and audit logs with Red Hat OpenShift Logging Operator.
We recommend using Elastic® Agent for the best possible experience! We will
also show how to format the logs to Elastic Common Schema ([ECS](https://www.elastic.co/guide/en/ecs/current/index.html))
for the best experience viewing, searching, and visualizing your logs. 
All examples in this blog are based on OpenShift 4.14.

## Why use OpenShift Logging Operator?

A lot of enterprise customers use OpenShift as their orchestrating solution.
The advantages of this approach are:
- It is developed and supported by Red Hat
- It can automatically update the OpenShift cluster along with the Operating
system to make sure that they are and remain compatible
- It can speed up developing life cycles with features like source to image
- It uses enhanced security

In our consulting experience, this latter aspect poses challenges and frictions
with OpenShift administrators when we try to install an Elastic Agent to collect
the logs of the pods. Indeed, Elastic Agent requires the files of the host to be
mounted in the pod, and it also needs to be run in privileged mode. (Read more
about the permissions required by Elastic Agent in the [official Elasticsearch®
Documentation](https://www.elastic.co/guide/en/fleet/current/running-on-kubernetes-standalone.html#_red_hat_openshift_configuration)). While the solution we explore in this post requires similar
privileges under the hood, it is managed by the OpenShift Logging Operator,
which is developed and supported by Red Hat.

## Which logs are we going to collect?
In OpenShift Container Platform, we distinguish
[three broad categories](https://docs.openshift.com/container-platform/4.14/logging/cluster-logging.html#logging-architecture-overview_cluster-logging) of logs:
audit, application, and infrastructure logs:

- **Audit logs** describe the list of activities that affected the system by users,
administrators, and other components.
- **Application logs** are composed of the container logs of the pods running in
non-reserved namespaces.
- **Infrastructure logs** are composed of container logs of the pods running in
reserved namespaces like openshift*, kube*, and default along with journald
messages from the nodes.

In the following, we will consider only audit and application logs for the sake
of simplicity. In this post, we will describe how to format audit and
application Logs in the format expected by the Kubernetes integration to take
the most out of Elastic Observability.

## Getting started
To collect the logs from OpenShift, we must perform some preparation steps
in Elasticsearch and OpenShift.

### Inside Elasticsearch
We first 
[install the Kubernetes integration assets](https://www.elastic.co/guide/en/fleet/8.11/install-uninstall-integration-assets.html#install-integration-assets). We are mainly interested in the index 
templates and ingest pipelines for the `logs-kubernetes.container_logs` and 
`logs-kubernetes.audit_logs`.

To format the logs received from the `ClusterLogForwarder` in 
[ECS](https://www.elastic.co/guide/en/ecs/current/index.html) format, we will
define a pipeline to normalize the container logs. The field naming convention
used by OpenShift is slightly different from that used by ECS. To get a list of
exported fields from OpenShift, refer to
[Exported fields | Logging | OpenShift Container Platform 4.14](https://docs.openshift.com/container-platform/4.14/logging/cluster-logging-exported-fields.html).
To get a list of exported fields of the Kubernetes integration, you can refer to
[Kubernetes fields | Filebeat Reference [8.11] | Elastic](https://www.elastic.co/guide/en/beats/filebeat/current/exported-fields-kubernetes-processor.html) and
[Logs app fields | Elastic Observability [8.11]](https://www.elastic.co/guide/en/observability/current/logs-app-fields.html). 
Further, specific fields like
`kubernetes.annotations` must be normalized by replacing dots with underscores.
This operation is usually done automatically by Elastic Agent.

```json
PUT _ingest/pipeline/openshift-2-ecs
{
  "processors": [
    {
      "rename": {
        "field": "kubernetes.pod_id",
        "target_field": "kubernetes.pod.uid",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.pod_ip",
        "target_field": "kubernetes.pod.ip",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.pod_name",
        "target_field": "kubernetes.pod.name",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.namespace_name",
        "target_field": "kubernetes.namespace",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.namespace_id",
        "target_field": "kubernetes.namespace_uid",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.container_id",
        "target_field": "container.id",
        "ignore_missing": true
      }
    },
    {
      "dissect": {
        "field": "container.id",
        "pattern": "%{container.runtime}://%{container.id}",
        "ignore_failure": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.container_image",
        "target_field": "container.image.name",
        "ignore_missing": true
      }
    },
    {
      "set": {
        "field": "kubernetes.container.image",
        "copy_from": "container.image.name",
        "ignore_failure": true
      }
    },
    {
      "set": {
        "copy_from": "kubernetes.container_name",
        "field": "container.name",
        "ignore_failure": true
      }
    },
    {
      "rename": {
        "field": "kubernetes.container_name",
        "target_field": "kubernetes.container.name",
        "ignore_missing": true
      }
    },
    {
      "set": {
        "field": "kubernetes.node.name",
        "copy_from": "hostname",
        "ignore_failure": true
      }
    },
    {
      "rename": {
        "field": "hostname",
        "target_field": "host.name",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "level",
        "target_field": "log.level",
        "ignore_missing": true
      }
    },
    {
      "rename": {
        "field": "file",
        "target_field": "log.file.path",
        "ignore_missing": true
      }
    },
    {
      "set": {
        "copy_from": "openshift.cluster_id",
        "field": "orchestrator.cluster.name",
        "ignore_failure": true
      }
    },
    {
      "dissect": {
        "field": "kubernetes.pod_owner",
        "pattern": "%{_tmp.parent_type}/%{_tmp.parent_name}",
        "ignore_missing": true
      }
    },
    {
      "lowercase": {
        "field": "_tmp.parent_type",
        "ignore_missing": true
      }
    },
    {
      "set": {
        "field": "kubernetes.pod.{{_tmp.parent_type}}.name",
        "value": "{{_tmp.parent_name}}",
        "if": "ctx?._tmp?.parent_type != null",
        "ignore_failure": true
      }
    },
    {
      "remove": {
        "field": [
          "_tmp",
          "kubernetes.pod_owner"
        ],
        "ignore_missing": true
      }
    },
    {
      "script": {
        "description": "Normalize kubernetes annotations",
        "if": "ctx?.kubernetes?.annotations != null",
        "source": "def keys = new ArrayList(ctx.kubernetes.labels.keySet()); for(k in keys) {\n  if (k.startsWith(\"app_kubernetes_io_component_\")) {\n    def sanitizedKey = k.replace(\"app_kubernetes_io_component_\", \"app_kubernetes_io_component/\");\n    ctx.kubernetes.labels[sanitizedKey] = ctx.kubernetes.labels[k];\n    ctx.kubernetes.labels.remove(k);\n  }\n}\n"
      }
    },
    {
      "script": {
        "description": "Normalize kubernetes namespace_labels",
        "if": "ctx?.kubernetes?.namespace_labels != null",
        "source": "def keys = new ArrayList(ctx.kubernetes.namespace_labels.keySet()); for(k in keys) {\n  if (k.indexOf(\".\") >= 0) {\n    def sanitizedKey = k.replace(\".\", \"_\");\n    ctx.kubernetes.namespace_labels[sanitizedKey] = ctx.kubernetes.namespace_labels[k];\n    ctx.kubernetes.namespace_labels.remove(k);\n  }\n}\n"
      }
    },
    {
      "script": {
        "description": "Normalize special Kubernetes Labels used in logs-kubernetes.container_logs-1.55.1 to determine service.name and service.version",
        "if": "ctx?.kubernetes?.labels != null",
        "source": "def keys = new ArrayList(ctx.kubernetes.labels.keySet()); for(k in keys) {\n  if (k.startsWith(\"app_kubernetes_io_component_\")) {\n    def sanitizedKey = k.replace(\"app_kubernetes_io_component_\", \"app_kubernetes_io_component/\");\n    ctx.kubernetes.labels[sanitizedKey] = ctx.kubernetes.labels[k];\n    ctx.kubernetes.labels.remove(k);\n  }\n}\n"
      }
    }
  ]
}
```


Similarly, to handle the audit logs like the ones collected by Kubernetes, we define an ingest pipeline:

```json
PUT _ingest/pipeline/openshift-audit-2-ecs
{
  "processors": [
    {
      "script": {
        "description": "Move all the 'kubernetes.audit' fields under 'kubernetes.audit' object",
        "source": "def audit = [:]; def keyToRemove = []; for(k in ctx.keySet()) {\n  if (k.indexOf('_') != 0 && !['@timestamp', 'data_stream', 'openshift', 'event', 'hostname'].contains(k)) {\n    audit[k] = ctx[k];\n    keyToRemove.add(k);\n  }\n} for(k in keyToRemove) {\n  ctx.remove(k);\n} ctx.kubernetes=[\"audit\":audit];\n"
      }
    },
    {
      "set": {
        "copy_from": "openshift.cluster_id",
        "field": "orchestrator.cluster.name",
        "ignore_failure": true
      }
    },
    {
      "set": {
        "field": "kubernetes.node.name",
        "copy_from": "hostname",
        "ignore_failure": true
      }
    },
    {
      "rename": {
        "field": "hostname",
        "target_field": "host.name",
        "ignore_missing": true
      }
    },
    {
      "script": {
        "if": "ctx?.kubernetes?.audit?.annotations != null",
        "description": "Normalize kubernetes audit annotations field as expected by the Integration",
        "source": "def keys = new ArrayList(ctx.kubernetes.audit.annotations.keySet());\n  for(k in keys) {\n    if (k.indexOf(\".\") >= 0) {\n      def sanitizedKey = k.replace(\".\", \"_\");\n      ctx.kubernetes.audit.annotations[sanitizedKey] = ctx.kubernetes.audit.annotations[k];\n      ctx.kubernetes.audit.annotations.remove(k);\n    }\n  }\n"
      }
    }
  ]
}
```
The main objective of the pipeline is to mimic what Elastic Agent is doing:
storing all audit fields under the `kubernetes.audit` object.

We are not going to use the conventional @custom pipeline approach because the
fields must be normalized before invoking the `logs-kubernetes.container_logs`
integration pipeline that uses fields like `kubernetes.container.name` and
`kubernetes.labels` to determine the fields `service.name` and `service.version`.
Read more about custom pipelines in Tutorial:
[Transform data with custom ingest pipelines | Fleet and Elastic Agent Guide [8.11]](https://www.elastic.co/guide/en/fleet/8.11/data-streams-pipeline-tutorial.html#data-streams-pipeline-one).

The OpenShift Cluster Log Forwarder writes the data in the indices app-write and
audit-write by default. It is possible to change this behavior, but it still
tries to prepend the prefix “`app`” and the suffix “`write`”, so we opted to
send the data to the default destination and use the reroute processor to send
it to the right data streams. Read more about the Reroute Processor in our blog
[Simplifying log data management: Harness the power of flexible routing with
Elastic](https://www.elastic.co/blog/simplifying-log-data-management-flexible-routing-elastic)
and our documentation [Reroute processor | Elasticsearch Guide [8.11] | Elastic](https://www.elastic.co/guide/en/elasticsearch/reference/current/reroute-processor.html).

In this case, we want to redirect the container logs (`app-write` index) to
`logs-kubernetes.container_logs` and the Audit logs (`audit-write`)
to `logs-kubernetes.audit_logs`:

```json
PUT _ingest/pipeline/app-write-reroute-pipeline
{
  "processors": [
    {
      "pipeline": {
        "name": "openshift-2-ecs",
        "description": "Format the Openshift data in ECS"
      }
    },
    {
      "set": {
        "field": "event.dataset",
        "value": "kubernetes.container_logs"
      }
    },
    {
      "reroute": {
        "destination": "logs-kubernetes.container_logs-openshift"
      }
    }
  ]
}
```

```json
PUT _ingest/pipeline/audit-write-reroute-pipeline
{
  "processors": [
    {
      "pipeline": {
        "name": "openshift-audit-2-ecs",
        "description": "Format the Openshift data in ECS"
      }
    },
    {
      "set": {
        "field": "event.dataset",
        "value": "kubernetes.audit_logs"
      }
    },
    {
      "reroute": {
        "destination": "logs-kubernetes.audit_logs-openshift.infrastructure"
      }
    }
  ]
}
```

Please note that given that `app-write` and `audit-write` do not follow the data
stream naming convention, we are forced to add the destination field in the 
reroute processor. The reroute processor will also fill up the 
[data_stream fields for us](https://www.elastic.co/guide/en/ecs/8.11/ecs-data_stream.html). 
Note that this step is done automatically by Elastic Agent at source.

Further, we create the indices with the default pipelines we created to reroute 
the logs according to our needs.

```json
PUT app-write
{
  "settings": {
    "index.default_pipeline": "app-write-reroute-pipeline"
  }
}
```

```json
PUT audit-write
{
  "settings": {
    "index.default_pipeline": "audit-write-reroute-pipeline"
  }
}
```

Basically, what we did can be summarized in this picture:

![Pipeline Graph](./images/pipelines.png)


Let us take the container logs. When the operator attempts to write in
the `app-write` index, it will invoke the default_pipeline
“`app-write-reroute-pipeline`” that formats the logs into ECS format and reroutes
the logs to `logs-kubernetes.container_logs-openshift` datastreams. This calls
the integration pipeline that invokes, if it exists, the
`logs-kubernetes.container_logs@custom` pipeline. Finally, the
`logs-kubernetes_container_logs` pipeline may reroute the logs to another data
set and namespace utilizing the `elastic.co/dataset` and `elastic.co/namespace`
annotations as described in the Kubernetes 
[integration documentation](https://docs.elastic.co/integrations/kubernetes/container-logs#rerouting-based-on-pod-annotations),
which in turn can lead to the execution of an another integration pipeline.

#### Create a user for sending the logs

We are going to use basic authentication because, at the time of writing, it is
the only supported authentication method for Elasticsearch in OpenShift logging.
Thus, we need a role that allows the user to `write` and `read` the `app-write`,
and `audit-write` logs (required by the OpenShift agent) and `auto_configure`
access to `logs-*-*` to allow custom Kubernetes rerouting:

```json
PUT _security/role/YOURROLE
{
  "cluster": [
    "monitor"
  ],
  "indices": [
    {
      "names": [
        "logs-*-*"
      ],
      "privileges": [
        "auto_configure",
        "create_doc"
      ],
      "allow_restricted_indices": false
    },
    {
      "names": [
        "app-write",
        "audit-write"
      ],
      "privileges": [
        "create_doc",
        "read"
      ],
      "allow_restricted_indices": false
    }
  ],
  "applications": [],
  "run_as": [],
  "metadata": {},
  "transient_metadata": {
    "enabled": true
  }
}
```

```json
PUT _security/user/YOUR_USERNAME
{
  "password": "YOUR_PASSWORD",
  "roles": [
    "YOURROLE"
  ]
}
```

### On OpenShift

On the OpenShift Cluster, we need to follow the 
[official documentation](https://docs.openshift.com/container-platform/4.14/logging/log_collection_forwarding/log-forwarding.html) 
of Red Hat on how to install the Red Hat OpenShift Logging and configure Cluster
Logging and the Cluster Log Forwarder.

We need to install the Red Hat OpenShift Logging Operator, which defines the
ClusterLogging and ClusterLogForwarder Resources. Afterward, we can define the
Cluster Logging resource:

```yaml
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  collection:
    logs:
      type: vector
      vector: {}

```

The Cluster Log Forwarder is the resource responsible for defining a daemon set
that will forward the logs to the remote Elasticsearch. Before creating it, we
need to create in the same namespace as the ClusterLogForwarder a secret
containing the Elasticsearch credentials for the user we created previously in
the namespace, where the ClusterLogForwarder will be deployed:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: elasticsearch-password
  namespace: openshift-logging
type: Opaque
stringData:
  username: YOUR_USERNAME
  password: YOUR_PASSWORD
```

Finally, we create the ClusterLogForwarder resource:

```yaml
kind: ClusterLogForwarder
apiVersion: logging.openshift.io/v1
metadata:
  name: instance
  namespace: openshift-logging
spec:
  outputs:
    - name: remote-elasticsearch
      secret:
        name: elasticsearch-password
      type: elasticsearch
      url: 'https://YOUR_ELASTICSEARCH_URL:443'
      elasticsearch:
        version: 8 # The default is version 6 with the _type field
  pipelines:
    - inputRefs:
        - application
        - audit
        # - infrastructure # Add this line if you need these logs
      name: enable-default-log-store
      outputRefs:
        - remote-elasticsearch

```

Note that we explicitly defined the version of Elasticsearch to be 8, otherwise
the `ClusterLogForwarder` will send the `_type` field, which is not compatible
with Elasticsearch 8 and that we collect only application and audit logs.

### Result

Once the logs are collected and passed through all the pipelines, the result is
very close to the out-of-the-box Kubernetes integration. There are important
differences, like the lack of host and cloud metadata information that don’t
seem to be collected (at least without an additional configuration). We can view
the Kubernetes container logs in the logs explorer:

![Result Picture](./images/result.png)


In this post, we described how you can use the OpenShift Logging Operator to
collect the logs of containers and audit logs. We still recommend leveraging
Elastic Agent to collect all your logs. It is the best user experience you can
get. No need to maintain or transform the logs yourself to ECS formatting.
Additionally, Elastic Agent uses API keys as the authentication method and
collects metadata like cloud information that allow you in the long run to do
[more](https://www.elastic.co/blog/optimize-cloud-resources-cost-apm-metadata-elastic-observability).

[Learn more about log monitoring with the Elastic Stack](https://www.elastic.co/observability/log-monitoring).