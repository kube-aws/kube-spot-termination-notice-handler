A Kubernetes DaemonSet to run 1 container per node to periodically polls the [EC2 Spot Instance Termination Notices](https://aws.amazon.com/jp/blogs/aws/new-ec2-spot-instance-termination-notices/) endpoint.
Once a termination notice is received, it will try to gracefully stop all the pods running on the Kubernetes node, up to 2 minutes before the EC2 Spot Instance backing the node is terminated.

## Installation

### Manual

    $ kubectl create -f spot-termination-notice-handler.daemonset.yaml

### Helm

A helm chart has been created for this tool, and at time of writing was in the `incubator` repository.

    $ helm install incubator/kube-spot-termination-notice-handler

## Available docker images/tags

Tags denotes Kubernetes/`kubectl` versions.
Using the same version for your Kubernetes cluster and spot-termination-notice-handler is recommended.

* `mumoshu/spot-termination-notice-handler:1.2.5`
* `mumoshu/spot-termination-notice-handler:1.3.0`
* `mumoshu/spot-termination-notice-handler:1.3.1`
* `mumoshu/spot-termination-notice-handler:1.3.2`
* `mumoshu/spot-termination-notice-handler:1.3.3`
* `kylegato/spot-termination-notice-handler:1.5.3`
* `kylegato/spot-termination-notice-handler:1.5.3-1` (Slack notifications feature is enabled since this version)
* `mumoshu/spot-termination-notice-handler:1.6.4`
* `mumoshu/spot-termination-notice-handler:1.7.0`

## Why use it

  * So that your kubernetes jobs backed by spot instances can keep running on another instances (typically on-demand instances)

## How it works

Each `spot-termination-notice-handler` pod polls the notice endpoint until it returns a http status `200`.
That status means a termination is scheduled for the EC2 spot instance running the handler pod, according to [my study](https://gist.github.com/mumoshu/f7f55e6e74aaf54f63d263326ca58ba3)).

Run `kubectl logs` against the handler pod to watch how it works.

```
$ kubectl logs --namespace kube-system spot-termination-notice-handler-ibyo6
This script polls the "EC2 Spot Instance Termination Notices" endpoint to gracefully stop and then reschedule all the pods running on this Kubernetes node, up to 2 minutes before the EC2 Spot Instance backing the node is terminated.
See https://aws.amazon.com/jp/blogs/aws/new-ec2-spot-instance-termination-notices/ for more information.
`kubectl drain minikubevm` will be executed once a termination notice is made.
Polling http://169.254.169.254/latest/meta-data/spot/termination-time every 5 second(s)
Fri Jul 29 07:38:59 UTC 2016: 404
Fri Jul 29 07:39:04 UTC 2016: 404
Fri Jul 29 07:39:09 UTC 2016: 404
Fri Jul 29 07:39:14 UTC 2016: 404
...
Fri Jul 29 hh:mm:ss UTC 2016: 200
```

## Building against a specific version of Kubernetes

Run `KUBE_VERSION=<your desired k8s version> make build` to specify the version number of k8s/kubectl.

## Slack Notifications
Introduced in version 0.9.2 of this application, you are able to setup a Slack incoming web hook in order to send slack notifications to a channel, notifying the users that an instance has been terminated.

Incoming WebHooks require that you set the SLACK_URL environmental variable as part of your PodSpec.

The URL should look something like: https://hooks.slack.com/services/T67UBFNHQ/B4Q7WQM52/1ctEoFjkjdjwsa22934

Slack Setup:
* Docs: https://api.slack.com/incoming-webhooks
* Setup: https://slack.com/apps/A0F7XDUAZ-incoming-webhooks


Show where things are happening by setting the `CLUSTER` environment variable to whatever you call your cluster.
Very handy if you have several clusters that report to the same Slack channel.

Example Pod Spec:

```
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: SLACK_URL
            value: "https://hooks.slack.com/services/T67UBFNHQ/B4Q7WQM52/1ctEoFjkjdjwsa22934"
          - name: CLUSTER
            value: development
```

![Example Slack Notification](http://i.imgur.com/UIUkyHv.png) (older version)
