# Pan
A simple package manager

<h3>Installing pan</h3>

    git clone https://github.com/selflex/pan.git
    cd pan
    sudo ./install.sh

<h3>Building package(s)</h3>

To build a package you need to create a recipe file or organize the ~/build/rcs directory so that it has sub directories containing recipe files. If there is no ~/build/rcs directory, pan will clone recipes from repository if it is enabled in the configuration file(/etc/pan.conf), and populate ~/build/rcs with subdirectories containing recipes. If you want to create a recipe for a program, just create ~/build/rcs/grep directory and save the recipe file as "recipe" inside it. ~/build/rcs/grep/recipe should look like this:

    pkg=grep
    ver=2.22
    rel=1
    grp=base
    dep=(glibc pcre texinfo)
    src=(ftp://ftp.gnu.org/gnu/grep/grep-$ver.tar.xz)
    sha=(ca91d22f017bfcb503d4bc3b44295491c89a33a3df0c3d8b8614f2d3831836eb)

    build() {
        ./configure --prefix=/usr
        make
    }

    package() {
        make DESTDIR=$pkgdir install

        rm -f $pkgdir/usr/share/info/dir
    }

The package variables has three letters that stands for: package, version, release, group, depends, source and SHA hash. The order is not important, and if there is no package dependency, then dep=() can be omitted. grp=() and sha=() are optional as well. If you rather want to use sha224sum=() variable as an example, it is an alias for sha=() with 224 bit hash. All the SHA hash bits are supported. Also src=() can be replaced by url=() if it is desired. There are also mkd=(), bak=() and opt=() variables, which stands for makedepends, backup and options. bak=(/etc/pan.conf), for instance, preserves the pan.conf when reinstalling or updating the pan package. Supported options are: (!)extract, (!)strip, (!)emptydirs, !buildflags, !makeflags, !subsrcdir and !stripcomponents. An exclamation point infront of an option disables a certain functionality when building a package.

Pan does automatically change directory to $srcdir/$pkg-$ver, ie ~/build/src/grep-2.22, when building a package. To disable automatically 'cd $srcdir/$pkg-$ver', add opt=(!subsrcdir) and $srcdir will be ~/build/src, but you need to manually add 'cd $pkg-$ver' into build() and package() functions. $pkgdir defaults to ~/build/pkg/grep-2.22. The configuration file is stored at /etc/pan.conf and build directories can be customized. In order to build the grep package, simply run:

    pan -b grep

Pan will first try to download the source arhive grep-2.22.tar.xz and save it to ~/build/tmp directory if it isn't there already, and then build the package. When it is finished building, it will compress the package into ~/build/arc/ directory as grep-2.22.pkg.tar.xz. If you have more than one recipes that have the same group name, ie base, you can simply build them altogether by running:

    pan -B base

<h3>Managing package(s)</h3>

Now that you have successfully built the grep package, you might want to install it. If you copy ~/build/arc/grep-2.22.pkg.tar.xz to /var/cache/pan/arc directory, then you will be able to install grep without specifying the package archive name. As root, you can simply run:

    pan -a grep

You can of course install grep somewhere into the home directory without being root user and there will be no need to copy grep-2.22.pkg.tar.xz to /var/cache/pan/arc directory. Use rootdir= argument to specify alternative root directory:

    pan -a grep rootdir=~/my_system_dir

If you want to install a package from ~/build/arc into the root directory, you need to explicitly tell pan the package archive name:

    pan -a ~/build/arc/grep-2.22.pkg.tar.xz

If you want to install the group of packages you've built, then type:

    pan -A base

If you want to remove grep from your system:

    pan -d grep

Removing group of packages are easily done like this:

    pan -D base

Say that grep has a newer release and you have built it and want to update it. Just run:

    pan -u grep

Updating packages belonging to a certain group:

    pan -U base

Updating all the packages works like this:

    pan -U

If you want to update the recipe directory without updating package(s), run:

    pan -u

If you have built and installed several packages and want to know if there are conflicting files, run:

    pan -c

If you want to know what packages are in a certain group, run:

    pan -g base

If you want to know how many groups there are, run:

    pan -G

Acquiring the package information can be done like this:

    pan -i grep

Sometimes you want to know where the files are installed of a certain package:

    pan -l grep

Finding out the file ownership can be done like this:

    pan -o /usr/bin/grep
