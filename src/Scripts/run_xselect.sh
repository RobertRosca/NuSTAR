echo "${highlight}Running init ${reset}"
source $HEADAS/headas-init.sh
source $CALDB/software/tools/caldbinit.sh

for xco in "$@"
do
xselect $xco
done
