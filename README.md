SQL Fiddle
==========

##About

See [the SQL Fiddle about page](http://sqlfiddle.com/about.html) page for background on the site.

## Getting the project up and running

Fork the code on github to a local branch for youself.

You are going to need [Vagrant](http://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) installed locally to get SQL Fiddle running. For VirtualBox, you will need to add a Host-only network for 10.0.0.0/24. Once you those installed and configured, and this project cloned locally, run this command from the root of your working copy:

    vagrant up

This will take a while to download the base image and all of the many dependencies. Once it has finished, you will have the software running in a set of VMs. You can now access your local server at [localhost:6081](http://localhost:6081/).

Note for Windows users - be sure that you run "vagrant up" as an administrator.

You should now have a functional copy of SQL Fiddle running locally.

I'm happy to entertain pull requests!

Thanks, 
Jake Feasel


## Running on AWS

With a bit of preparation, you should be able to deploy the whole app into Amazon Web Services. See the comments in Vagrantfile for an example config that you can fill in with your own AWS account details.

You will need to install the vagrant-aws plugin. See the plugin site here for details: https://github.com/mitchellh/vagrant-aws

Be sure to also install the "dummy" box.

You may also wish to have automated backups of your sqlfiddle database to S3. If so, you will need to add a .s3cfg file under vagrant_scripts. This file will not be added to the git repo (it is ignored) but if present the PostgreSQL server will automatically schedule backups to write to your account. The .s3cfg file is produced by "s3cmd" - check this site for more details: http://s3tools.org/s3cmd-howto