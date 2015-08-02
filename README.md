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

To build a package you need to create the /pkg/rcs directory so that it contains the recipe file. If there is no /pkg/rcs directory, Pan will automatically clone recipes from https://github.com/gnurama/recipes and populate /pkg/rcs with subdirectories containing recipes. But if you want to do it yourself, just create /pkg/rcs/grep directory and save the recipe file as "recipe" inside it. /pkg/rcs/grep/recipe should look like this:

    n=grep
    v=2.21
    r=1
    s=base
    d=('glibc' 'pcre' 'texinfo')
    u=ftp://ftp.gnu.org/gnu/$n/$n-$v.tar.xz

    build() {
        ./configure --prefix=/usr
        make
    }

    package() {
        make DESTDIR=$pkg install

        rm -f $pkg/usr/share/info/dir
    }

The source information has letters that stands for: (n)ame, (v)ersion, (r)elease, (s)ection, (d)ependency and (u)rl. The order is not important, and if there is no package dependency, then d can be omitted. Pan does automatically cd to ~/build/src/grep-2.21. If you want to cd $src(~/build/src) directory, then add "p=./", which stands for (p)ath. $pkg defaults to ~/build/pkg/grep-2.21. The configuration file is stored at /etc/pan.conf, and can be customized if needed. Now, to build the grep package, simply run:

    pan -b grep

Pan will build and compress the package into /pkg/arc/ directory as grep-2.21.pkg.tar.xz. If you have more than one recipes that have the same section, ie base, you can simply build them altogether by running:

    pan -B base

<h3>Managing package(s)</h3>

Now that you have successfully built the grep package, you might want to install it by typing:

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

If you want to update the /pkg/rcs without updating package(s), run:
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
