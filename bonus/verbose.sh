!#/bin/sh

echo "  === Write \e[4;32mFamine\e[0m hexdump in \e[4;34m./fam_dump\e[0m  ==="
# hexdump -C Famine > cl_fam_dump 
# objdump -d Famine > cl_fam_obj
echo 'Done.'
echo

echo "  === Copy test dir in \e[4;34m/tmp\e[0m ==="
if [ -d /tmp/test ]; then
	rm -r /tmp/test
fi
cp -vr ../test /tmp/ 
echo "  ===  tree \e[4;32m/tmp/test\e[0m  ==="
tree /tmp/test
echo

echo "  === Write clean \e[4;32m/tmp/test/sample64\e[0m hexdump in \e[4;34m./cl_dump\e[0m  ==="
# hexdump -C /tmp/test/sample64 > cl_dump 
echo 'Done.'
echo

echo "  === Make ==="
make 
echo

echo "  === Run ./Famine ==="
# gdb Famine
# valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --track-fds=yes --vgdb-error=1 -q ./Famine 
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --track-fds=yes -q ./Famine 
echo "Done."
echo 'strings /tmp/test/sample64 | grep anvincen-eedy'
strings /tmp/test/sample64 | grep anvincen-eedy
echo

echo "  === Write infected \e[4;32m/tmp/test/sample64\e[0m hexdump in \e[4;34m./inf_dump\e[0m ==="
# hexdump -C /tmp/test/sample64 > inf_dump 
echo 'Done.'
echo

echo "  === Put clean executables in \e[4;34m/tmp/test\e[0m ==="
cp -v ./test/OK/ls ./test/OK/pwd /tmp/test/
echo

echo "  === Write clean \e[4;32m/tmp/test/ls\e[0m hexdump in \e[4;34m./cl_dump_1\e[0m  ==="
# hexdump -C /tmp/test/ls > cl_dump_1
echo 'Done.'
echo

echo "  === ./tmp/test/sample64 ===\e[0m"
sudo valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --track-fds=yes -q /tmp/test/sample64
# sudo gdb /tmp/test/sample64
echo 'strings /tmp/test/ls | grep anvincen-eedy'
strings /tmp/test/ls | grep anvincen-eedy
echo

echo "  === Write infected \e[4;32m/tmp/test/ls\e[0m hexdump in \e[34m./inf_dump_1\e[0m ==="
# hexdump -C /tmp/test/ls > inf_dump_1
echo "Done."