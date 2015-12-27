# Setting up your Ansible project to build and test using Docker on CircleCI

## Why I did this

I have an Ansible project which configures our VMs for our customers. Being a big fan of automation and testing I wanted to test using CI. Our CI platform of choice here at InfluxData is currently CircleCI. Up until this point, all of my Ansible development has used Vagrant using VirtualBox. Unfortunately, CircleCI doesn't support that outof the box. However, they do enable Docker. Here's a sample project which show how I set this up.

## How I did this

#### Assumptions

This article assumes familiarity with CircleCI, Ansible, Docker and Vagrant. I've skipped over the basics of installation and use of those tools to keep this short. Besides, there are already lots of good resources out there on these tools.

### The Vagrant File - Local Testing
First we start with a Vagrant config so I can test locally in a similar environment to what I'll be running in Circle and production. It builds the docker image on provision. I've chosen to use William Yeh's excellent [Docker Enabled Vagrant](https://github.com/William-Yeh/docker-enabled-vagrant) project as a starting point.

```
# Vagrantfile
Vagrant.configure(2) do |config|

    config.vm.box = "williamyeh/ubuntu-trusty64-docker"

    config.vm.define "ansible-docker-test" do |machine|
      machine.vm.provider "virtualbox"
    end

    # ==> Executing Ansible...
    config.vm.provision "shell", inline: <<-SHELL
      cd /vagrant
      docker build -t test-box .
    SHELL
end
```

You can start by running `vagrant up`.
From here on out you can keep testing your playbooks by running `vagrant provision`.

### The Docker File

The following Dockerfile is very simple and effectively just runs the playbooks for you after downloading the dependencies.
    
It uses the Ansible docker image from William Yeh. See more: 

https://hub.docker.com/r/williamyeh/ansible/
https://github.com/William-Yeh/docker-ansible

```
# Dockerfile
FROM williamyeh/ansible:ubuntu14.04-onbuild
RUN ansible-playbook-wrapper
```

### The Playbook

Here we'll add a playbook which adds a file to test against.  These simple tasks represent the configuration that you would be doing in your normal playbook. In this case, we’re just touching a file which we can then test against later.
    
You'll note that on line 6, this playbook actually sets the file as "absent." This is because whenever we're writing a test, we want to make sure it works by making sure it is Red, or broken. For more on this process, google for "Red Green Refactor" and you'll find many resources on the philosophy behind this.
    
See the docker image https://github.com/William-Yeh/docker-ansible which explains that the base docker image we're using here defaults to a playbook location of `./playbook.yml`. You can change this following his instructions.

```
# playbook.yml
---
- name: Sample Play
  hosts: all
  tasks:
  - file: path=/foo state=directory
  - file: path=/foo/test.txt state=absent
```

### The Test

Add a test file that returns non-zero if anything fails. This file runs an `ls` command on the file which should be there from the Ansible play. If it was not successful, then the playbook doesn’t work.

```
# test.sh

# Exit out if an error occurs
set -e

# Look for the file created by the playbook and put the results in a text file
# on the test machine
docker run -i test-box ls /foo/test.txt > result.test.txt

# Test that the results file contains the path to the file.
echo "==> Validating the test results..."
sh -c 'grep "foo/test.txt" result.test.txt'
```

### Configure CircleCI

Next, we'll create a CircleCI configuration file.  It builds the docker container, calling it `test-box`. In the tests, it runs the test file created earlier.

```
# circle.yml

machine:
  services:
    - docker

dependencies:
  override:
    - docker info
    - docker version
    - docker build  -t test-box .

test:
  override:
    - sh -c ./test.sh 
```

At this point, set up your CircleCI project and run the first build. You should see that the build is broken with a message like:

```
ls: cannot access /foo/test.txt: No such file or directory sh -c ./test.sh
returned exit code 2
```

If you remember, this is because we intentionally broke our playbook to see if our tests work.

### Fix the playbook

Fix the playbook so that the tests go green.

We'll change the line that reads

`- file: path=/foo/test.txt state=absent`

to

`- file: path=/foo/test.txt state=touch`

Push this change to your repo and you should now see

```
==> Validating the test results...
/foo/test.txt
```

## Conclusion

And there you go. You have a green build! Enjoy your continuous testing!

## Extras

### Optimizing

You may find that your builds are a little slow. Especially if you're relying on external connections like we are for the base docker image. I added some caching that speeds things up a bit after the cache is warmed up.

  Due to the large base image docker image, we're saving the produced docker image to ~/docker/image.tar, which is cached, and loading it before building. This avoids having to download it from outside CircleCI's network every time.
    
For more information check out https://circleci.com/docs/docker
    
An in depth use case can be found at http://tschottdorf.github.io/cockroach-docker-circleci-continuous-integration/

Here's the final circle.yml with the new caching added:

```
machine:
  services:
    - docker

dependencies:
  cache_directories:
    - "~/docker"
  override:
    - docker info
    - docker version
    - if [[ -e ~/docker/image.tar ]]; then docker load -i ~/docker/image.tar; fi
    - docker build --rm=false -t testbox .
    - mkdir -p ~/docker; docker save testbox > ~/docker/image.tar

test:
  override:
    - sh -c ./test.sh
```
