A Kubernetes DaemonSet to run 1 container per node to periodically polls the [EC2 Spot Instance Termination Notices](https://aws.amazon.com/jp/blogs/aws/new-ec2-spot-instance-termination-notices/) endpoint.
Once a termination notice is received, it will try to gracefully stop all the pods running on the Kubernetes node, up to 2 minutes before the EC2 Spot Instance backing this node is terminated.

## Usage

    $ kubectl create -f spot-termination-notice-handler.daemonset.yaml

## Why use it

  * So that your kubernetes jobs backed by spot instances can keep running on another instances(typically on-demand instances)
