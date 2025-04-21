#!/bin/sh

echo "  === Make ==="
make re
echo

echo "  === Copy test dir in \e[4;34m/tmp\e[0m ==="
if [ -d /tmp/test ]; then
	rm -r /tmp/test
fi
cp -vr ../test /tmp/ 
cp -vr ../test/KO/infected /tmp/test/infected
echo "  ===  tree \e[4;32m/tmp/test\e[0m  ==="
tree /tmp/test
echo

hexdump -C ../test/sample64 > dump_cl_sample
echo "  === Run ./Famine ==="
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --track-fds=yes -q ./Famine 
# gdb Famine
echo "Done."
hexdump -C /tmp/test/sample64 > dump_sample
hexdump -C Famine > ./dump_famine
echo
echo 'strings /tmp/test/sample64 | grep anvincen-eedy'
strings /tmp/test/sample64 | grep anvincen-eedy
echo
echo 'strings /tmp/test/infected | grep anvincen-eedy'
strings /tmp/test/infected | grep anvincen-eedy
echo

echo "  === Put clean executables in \e[4;34m/tmp/test\e[0m ==="
# cp -v ../test/OK/ls ../test/OK/pwd /tmp/test/
cp -v ../test/OK/ls /tmp/test/
echo

echo "  === ./tmp/test/sample64 ===\e[0m"
# valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --track-fds=yes -q /tmp/test/sample64
gdb /tmp/test/sample64
# /tmp/test/sample64
echo
echo 'strings /tmp/test/ls | grep anvincen-eedy'
strings /tmp/test/ls | grep anvincen-eedy
echo
echo 'strings /tmp/test/pwd | grep anvincen-eedy'
strings /tmp/test/pwd | grep anvincen-eedy
echo
echo 'strings /tmp/test/infected | grep anvincen-eedy'
strings /tmp/test/infected | grep anvincen-eedy
echo
