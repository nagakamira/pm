# pm
A simple package manager.
pm is used by [GNUrama Linux] (http://www.gnurama.org)

<h3>Installing pm</h3>

    git clone https://github.com/selflex/pm.git
    cd pm
    sudo ./install.sh

<h3>Requirements</h3>

    bash, git, curl, fakeroot, tar, libarchive, gzip
    fakechroot (optional)

<h3>Building package(s)</h3>

To build a package you need to create a recipe file or organize the ~/build/rcs directory so that it has sub directories containing recipe files. If there is no ~/build/rcs directory, pm will clone recipes from a repository if it is enabled in the configuration file, and populate ~/build/rcs with subdirectories containing recipes. If you want to organize a recipe collection of your own, just create ~/build/rcs/grep directory, as an example, and save the recipe file as "recipe" inside it. ~/build/rcs/grep/recipe should look like this:

```shell
pkg=grep
ver=2.25
rel=1
sum="A string search utility"
lic=GPL3
url=http://www.gnu.org/software/grep/grep.html
grp=base
dep=(glibc pcre texinfo)
src=(ftp://ftp.gnu.org/gnu/grep/grep-$ver.tar.xz)
sha=(e21e83bac50450e0d0d61a42c154ee0dceaacdbf4f604ef6e79071cb8e596830)

build() {
    ./configure --prefix=/usr
    make
}

package() {
    make DESTDIR=$pkgdir install

    rm -f $pkgdir/usr/share/info/dir
}
```

The package variables have three letters that stands for: package, version, release, summary, license, url, group, depends, source and SHA hash. The order is not important, and if there is no package dependency, then dep=() can be omitted. sum=, lic=, url=, grp=() and sha=() are optional as well. All the SHA hash bits are supported when using sha=(). There are also mkd=(), bak=() and opt=() variables, which stands for makedepends, backup and options. bak=(/etc/pm.conf), for instance, preserves the pm.conf when reinstalling or updating the pm package. Supported options are: (!)extract, (!)strip, (!)emptydirs, !buildflags, !makeflags and !subsrcdir. An exclamation point infront of an option disables a certain functionality when building a package.

pm does automatically change directory to $srcdir/$pkg-$ver, ie ~/build/src/grep-2.25, when building a package. To disable automatically 'cd $srcdir/$pkg-$ver', add opt=(!subsrcdir) and $srcdir will be ~/build/src, but you need to manually add 'cd $pkg-$ver' into build() and package() functions. $pkgdir defaults to ~/build/pkg/grep-2.25. The configuration file is stored at /etc/pm.conf and build directories can be customized. In order to build the grep package, simply run:

    pm -b recipe

Or if you want to build from the recipe collection directory(~/build/rcs):

    pm -b grep

pm will first try to download the source arhive grep-2.25.tar.xz and save it to ~/build/tmp directory if it isn't already there, and then build the package. When it is finished building, it will compress the package into ~/build/arc/ directory as grep-2.25.pkg.tar.xz. If you have more than one recipes that have the same group name, ie base, you can simply build them altogether by running:

    pm -B base

<h3>Managing package(s)</h3>

Now that you have successfully built the grep package, you might want to install it. If you copy ~/build/arc/grep-2.25.pkg.tar.xz to /var/cache/pm/arc directory, then you will be able to install grep without specifying the package archive name. As root, you can simply run:

    pm -a grep

You can of course install grep somewhere into the home directory without being root user and there will be no need to copy grep-2.25.pkg.tar.xz to /var/cache/pm/arc directory. Use rootdir= argument to specify alternative root directory:

    pm -a grep rootdir=~/my_system_dir

If you want to install a package from ~/build/arc into the root directory, you need to explicitly tell pm the package archive name:

    pm -a ~/build/arc/grep-2.25.pkg.tar.xz

If you want to install the group of packages you've built, then type:

    pm -A base

If you want to remove grep from your system:

    pm -d grep

Removing group of packages are easily done like this:

    pm -D base

Say that grep has a newer release and you have built it and want to update it. Just run:

    pm -u grep

Updating packages belonging to a certain group:

    pm -U base

Updating all the packages works like this:

    pm -U

If you want to update the recipe directory without updating package(s), run:

    pm -u

If you have built and installed several packages and want to know if there are conflicting files, run:

    pm -c

If you want to know what packages are in a certain group, run:

    pm -g base

If you want to know how many groups there are, run:

    pm -G

Acquiring the package information can be done like this:

    pm -i grep

Sometimes you want to know where the files are installed of a certain package:

    pm -l grep

When you use mkd=() variable, it is always a good practice to install make dependencies before building a package, since pm will install runtime dependencies as well. It can be done like this:

    pm -m grep

Finding out the file ownership can be done like this:

    pm -o /usr/bin/grep

To automatically generate SHA hash(the default is 256 bit), which can be overriden by any sha=() alias, simply run:

    pm -s grep
