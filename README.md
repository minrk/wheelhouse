# My Wheelhouse

A script for building wheels of common tools.

I have no expectation that the resulting wheels will be functional on anyone else's machine,
but people are welcome to try out the results [here](http://kerbin.bic.berkeley.edu/wheelhouse),
with:

    pip install --find-links=http://kerbin.bic.berkeley.edu/wheelhouse numpy scipy matplotlib

or

    pip install --pre --find-links=http://kerbin.bic.berkeley.edu/wheelhouse/nightly numpy scipy matplotlib

for nightlies.

# LaunchAgent

Edit `net.minrk.wheelhouse.plist` with the path to wheelhouse.sh,
and copy it to ~/Library/LaunchAgents in order to automatically build your own wheels
on a schedule. On Linux, you can set it up with a cron job.

