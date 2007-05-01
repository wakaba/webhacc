#!/bin/sh
find -name ChangeLog | xargs cvs diff | grep "^\+" | sed -e "s/^\+//; s/^\+\+ .\//++ html\//" > .cvslog.tmp
cvs commit -F .cvslog.tmp $1 $2 $3 $4 $5 $6 $7 $8 $9 
rm .cvslog.tmp

## $Date: 2007/05/01 09:25:13 $
## License: Public Domain
