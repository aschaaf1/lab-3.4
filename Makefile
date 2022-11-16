CFLAGS = $(DEFINE) -Wall -Wshadow -Wunreachable-code -Wredundant-decls -Wmissing-declarations -Wold-style-definition -Wmissing-prototypes -Wdeclaration-after-statement -Wno-return-local-addr -Wuninitialized -Werror -Wunsafe-loop-optimizations

all: primesMT

primesMT: primesMT.o
	gcc $(CFLAGS) -o primesMT primesMT.o -pthread

primesMT.o: primesMT.c
	gcc $(CFLAGS) -c primesMT.c -pthread

clean:
	rm -f *.o *~ \#*
