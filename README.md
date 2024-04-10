# Using [go-task](https://taskfile.dev/) makes this less miserable

This is all we need:
```bash
cd onejuly
task
```

If our Taskfile.yml is correct then our dependencies are built for us without having to fiddle.

This is super.


## ~~FIXME~~ Parents should reep their children when they change

If we have this set of 4 images:

- t4
- t3
- t2
- t1

and image t4 is built from t3, then to rebuild t3, we can use `task t3 --force` which has two problems:

1. t1, t2 are rebuilt but this is not helpful

2. t4 is not rebuit, but it should be since t4 is based off t3 and its assumed t3 has changed because we're rebuilding it.  So containers based off image t4 are incorrect since they don't reflect the current state.  Rebuilding t4 based off the new t3 is required.


It reminds me of terraform's taint functionality.

This fixes both problems:
```bash
incus image rm t3 t4
incus rm --force t3 t4
task
```

...but


1. its manual, hence error prone

2. the parent t3 needs to know who its children are (t4) so it can kill them off





There must be a way to fix this...


In `task` We need some way to query descendants.

And there is using [source/generates/timestamps](https://taskfile.dev/usage/#by-fingerprinting-locally-generated-files-and-their-sources) allows this to work nicely.

My taskfile is geting hideous, but maybe I'll see an easy way to cleanup later.



# Bootstrapping container images to speed up testing

Successively build on previous image so next test is faster.

```bash
# create image ringgem-ubuntu based off images:ubuntu/22.04/cloud
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=ringgem --var BaseImage=images:ubuntu/22.04/cloud --var OutputImageAlias=ringgem-ubuntu

# create image t1-ringgem based off ringgem-ubuntu
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=t1 --var BaseImage=ringgem-ubuntu --var OutputImageAlias=t1-ringgem

# create image t2-t1-ringgem based off t1-ringgem
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=t2 --var BaseImage=t1-ringgem --var OutputImageAlias=t2-t1-ringgem

vim ringgem.sh #adjust cloud-init
vim t1.sh #adjust cloud-init
vim t2.sh #adjust cloud-init

time { bash -ex ringgem.sh && bash -ex t1.sh && bash -ex t2.sh && echo done; }

...
```


# TODO

- try out the declarative [terraform-provider-incus](https://github.com/lxc/terraform-provider-incus/tree/main?tab=readme-ov-file#terraform-provider-incus), I expect its much better than this imperative nonsense

- Not sure if using boilerplate is as good as jinja [template inheritance](https://jinja.palletsprojects.com/en/3.1.x/templates/#template-inheritance).  I think you get inheritance from boilerplate [partials](https://github.com/gruntwork-io/boilerplate?tab=readme-ov-file#partials), but that seems like jinja [macros](https://jinja.palletsprojects.com/en/3.1.x/templates/#macros) which are not nearly as powerful as jinja template inheritance.  I've not yet used partials.





## I'm tempted to head down the systemd-in-podman containers rabbithole


All this graph dependency tracking is automatic in docker layers but I need systemd.

Now I learn that podman quadlet is the thing that makes using systemd in containers work.  Ooff, more rabbit holes...
