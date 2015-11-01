# Pan
A simple package manager

<h3>Objectives</h3>

    Be close to the source when building it.
    Reduce any layers or abstractions.
    Provide minimal tools for maintenance.
    Keep the system clean, simple and personal.

<h3>Rationale</h3>

Pan stems from the principle that GNU/Linux user experience can be both fun and educational, once the user is able to utilise the development tools that creates a unique and personal operating system. Building and managing a free and open-source software should be simple and easy with Pan, without any complexities or abstractions, so that everyone can benefit from it.

The GNU/Linux community is driven by a strong and cohesive force that brings forth a fully functional operating system containing lots of packages. Packages, like the cells in every organism, are the building blocks of GNU/Linux. Once the desired packages are built, one can distribute an entire operating system targeting various platforms and user bases. Pan, not only gives you the opportunity to build packages, but also helps you distribute them and build the GNU/Linux operating system from scratch.

<h3>Installing Pan</h3>

    git clone https://github.com/selflex/pan.git
    cd pan
    sudo ./install.sh

<h3>Building package(s)</h3>

To build a package you need to create a recipe file or organize the ~/build/rcs directory so that it has sub directories containing recipe files. If there is no ~/build/rcs directory, pan will clone recipes from repository if it is enabled in the configuration file(/etc/pan.conf), and populate ~/build/rcs with subdirectories containing recipes. If you want to create a recipe for a program, just create ~/build/rcs/grep directory and save the recipe file as "recipe" inside it. ~/build/rcs/grep/recipe should look like this:

    pkg=grep
    ver=2.21
    rel=1
    grp=base
    dep=(glibc pcre texinfo)
    src=(ftp://ftp.gnu.org/gnu/grep/grep-$ver.tar.xz)
    sha=(5244a11c00dee8e7e5e714b9aaa053ac6cbfa27e104abee20d3c778e4bb0e5de)

    build() {
        ./configure --prefix=/usr
        make
    }

    package() {
        make DESTDIR=$pkgdir install

        rm -f $pkgdir/usr/share/info/dir
    }

The package variables has three letters that stands for: package, version, release, group, depends, source and sha2. The order is not important, and if there is no package dependency, then dep can be omitted. grp and sha are optional as well. Pan does automatically change directory to $srcdir/$pkg-$ver, ie ~/build/src/grep-2.21, when building a package. $pkgdir defaults to ~/build/pkg/grep-2.21. The configuration file is stored at /etc/pan.conf and build directories can be customized. In order to build the grep package, simply run:

    pan -b grep

Pan will first try to download the source arhive grep-2.21.tar.xz and save it to ~/build/tmp directory if it isn't there already, and then build the package. When it is finnished building, it will compress the package into ~/build/arc/ directory as grep-2.21.pkg.tar.xz. If you have more than one recipes that have the same group, ie base, you can simply build them altogether by running:

    pan -B base

<h3>Managing package(s)</h3>

Now that you have successfully built the grep package, you might want to install it. If you copy ~/build/arc/grep-2.21.pkg.tar.xz to /var/cache/pan/arc directory, then you will be able to install grep into the system, otherwise you need to specify root directory when installing as a regular user:

    pan -a grep rootdir=my/install/path

As root, you can simply run:

    pan -a grep

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
