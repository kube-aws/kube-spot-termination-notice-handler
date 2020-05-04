A Kubernetes DaemonSet to run 1 container per node to periodically polls the [EC2 Spot Instance Termination Notices](https://aws.amazon.com/blogs/aws/new-ec2-spot-instance-termination-notices/) endpoint.
Once a termination notice is received, it will try to gracefully stop all the pods running on the Kubernetes node, up to 2 minutes before the EC2 Spot Instance backing the node is terminated.

## Installation

### Helm

A helm chart has been created for this tool, and at time of writing was in the `stable` repository.

    $ helm install stable/k8s-spot-termination-handler

## Available docker images/tags

Tags denotes Kubernetes/`kubectl` versions.
Using the same version for your Kubernetes cluster and spot-termination-notice-handler is recommended.
Note that the `-1` (or similar) is the revision of this tool, in case we need versioning.

* `kubeaws/kube-spot-termination-notice-handler:1.8.5-1`
* `kubeaws/kube-spot-termination-notice-handler:1.9.0-1`
* `kubeaws/kube-spot-termination-notice-handler:1.10.11-2`
* `kubeaws/kube-spot-termination-notice-handler:1.11.3-1`
* `kubeaws/kube-spot-termination-notice-handler:1.12.0-2`
* `kubeaws/kube-spot-termination-notice-handler:1.13.7-1`
* `kubeaws/kube-spot-termination-notice-handler:1.15.10-1`

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
Introduced in version 0.9.2 of this application (the @mumoshu version), you are able to setup a Slack incoming web hook in order to send slack notifications to a channel, notifying the users that an instance has been terminated.

Incoming WebHooks require that you set the SLACK_URL environmental variable as part of your PodSpec.

You can also set SLACK_CHANNEL to send message to different slack channel insisted of default slack webhook url's channel.

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
          - name: SLACK_CHANNEL
          - value: "#devops"
          - name: CLUSTER
            value: development
```

## Sematext Cloud Event Notifications

The [Sematext Cloud](https://sematext.com/cloud) event URL is different for Europe and USA and includes the application token for your monitored App.

* USA URL: https://event-receiver.sematext.com/APPLICATION_TOKEN/event
* Europe URL: https://event-receiver.eu.sematext.com/APPLICATION_TOKEN/event

Sematext Setup:
* You get the APPLICATION_TOKEN when you create a [Docker monitoring app](https://sematext.com/docker/) in Sematext Cloud.
* API Docs: https://sematext.com/docs/events/#adding-events

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
          - name: SEMATEXT_URL
            value: "https://event-receiver.sematext.com/APPLICATION_TOKEN/event"
          - name: CLUSTER
            value: development
          - name: DETACH_ASG
            value: "true"
```

## Wechat Notifications

Incoming WebHooks require that you set the WECHAT_URL and WECHAT_KEY environmental variables as part of your PodSpec.

The URL should look something like: https://pushbear.ftqq.com/sub?key=3488-876437815599e06514b2bbc3864bc96a&text=SpotTermination&desp=SpotInstanceDetainInfo

Wechat Setup:
* You get the WECHAT_KEY by [pushbear](http://pushbear.ftqq.com/admin/)
* You bind WECHAT_KEY to a QR code after you create a [Wechat Service account](https://mp.weixin.qq.com/?lang=en_US).
* API Docs: http://pushbear.ftqq.com/admin/ ; https://mp.weixin.qq.com/?lang=en_US

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
          - name: WECHAT_URL
            value: "https://pushbear.ftqq.com/sub"
          - name: WECHAT_KEY
            value: "3488-876437815599e06514b2bbc3864bc96a"
          - name: CLUSTER
            value: development
          - name: DETACH_ASG
            value: "true"
```

## AutoScaling Detachment

**This feature currently only supports simple autoscaling - no spot fleet or similar.**

If you set the environment variable `DETACH_ASG` to _any value other than_ `false`, the handler will detach the instance from the ASG, which may bring a replacement instance up sooner.

The autoscaling group name is automatically detected by the handler.

## Credits

kube-spot-termination-notice-handler is a collaborative project to unify [@mumoshu and @kylegato's initial work](https://github.com/mumoshu/kube-spot-termination-notice-handler) and [@egeland's fork with various enhancements and simplifications](https://github.com/egeland/kube-spot-termination-notice-handler).

The project is currently maintained by:

- @egeland
- @kylegato
- @mumoshu
