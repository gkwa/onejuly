# Bootstrapping container images to speed up testing

Successively build on previous image so next test is faster.

```bash
# create image ringgem-ubuntu based off images:ubuntu/22.04/cloud
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=ringgem --var BaseImage=images:ubuntu/22.04/cloud --var OutputImageAlias=ringgem-ubuntu
vim ringgem.sh #adjust cloud-init
bash -ex ringgem.sh

# create image t1-ringgem based off ringgem-ubuntu
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=t1 --var BaseImage=ringgem-ubuntu --var OutputImageAlias=t1-ringgem
vim t1.sh #adjust cloud-init
bash -ex t1.sh

# create image t2-t1-ringgem based off t1-ringgem
boilerplate --template-url=https://github.com/taylormonacelli/onejuly/archive/refs/heads/master.zip//onejuly-master/templates --output-folder=. --var ContainerName=t2 --var BaseImage=t1-ringgem --var OutputImageAlias=t2-t1-ringgem
vim t2.sh #adjust cloud-init
bash -ex t2.sh

...
```


# TODO

- try out [terraform-provider-incus](https://github.com/lxc/terraform-provider-incus/tree/main?tab=readme-ov-file#terraform-provider-incus), I expect its much better than this imperative nonsense
