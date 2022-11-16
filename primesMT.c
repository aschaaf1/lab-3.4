// Alan Schaaf
// November 15, 2022
//
// this is a revised version of my orignal submission in order to
// remove any functions that are not used

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>

#ifndef DEF_THREADS
# define DEF_THREADS 1
#endif // DEF_THREADS

#ifndef DEF_LIMIT
# define DEF_LIMIT 10240
#endif // DEF_LIMIT


typedef struct BitBlocks_s 
{
	uint32_t bits;
	pthread_mutex_t mutex;
} BitBlocks_t;

static BitBlocks_t * array = NULL;
static int num_threads = DEF_THREADS;
static int limit = DEF_LIMIT;
static int root = 0;
static int size = 0;
static bool is_verbose = false;
//intialize bits in array of data structs to 0, and init mutex
void initialize_array(void);

//free mutex
void free_mutex(void);

//function to find the low square root of number
int find_root(int);

//function to print the numbers that are marked as prime
void print_primes(void);

//sieve function using multi threading
void * sieve(void *);

int main (int argc, char * argv[])
{
	pthread_t * threads = NULL;
	//first process the command line arguments
	int opt = -2;


	while (opt != -1)
	{
		opt = getopt(argc, argv, "t:u:hv");

		//switch statement to process opt
		switch(opt)
		{
			case 't':
				num_threads = atoi(optarg);
				break;
			case 'u':
				limit = atoi(optarg);
				break;
			case 'h':
				printf("help\n");
				printf("-t -- specify number threads\n");
				printf("-u -- specify upper limit of numbers\n");
				printf("-v -- verbose processing\n");
				exit(0);
				break;
			case 'v':
				is_verbose = true;
				break;
		}
	}
	//assigning values now that we have processed command line
	size = (limit/32) + 1;
	array = malloc(size * sizeof(BitBlocks_t));
	root = find_root(limit);

	//intializing BitBlock array
	initialize_array();
	//allocating threads
	threads = malloc(num_threads * sizeof(pthread_t));

	if (is_verbose)
	{
		fprintf(stderr, "VERBOSE ENABLED\n");
		fprintf(stderr, "threads: %d\nupperbound: %d\n", num_threads, limit);
	}

	//creating threads
	for (long i = 0, start = 3; i < num_threads; ++i, start += 2)
	{
		if (is_verbose)
		{
			fprintf(stderr, "create thread: %ld\n", i+1);
		}
		pthread_create(&threads[i], NULL, sieve, (void *) start);
	}

	//joining threads
	for (long i  = 0; i < num_threads; ++i)
	{
		if (is_verbose)
		{
			fprintf(stderr, "join thread: %ld\n", i+1);
		}
		pthread_join(threads[i], NULL);
	}
	//printing all prime numbers
	print_primes();

	//destroy mutexs
	free_mutex();
	//deallocate threads
	free(threads);
	//deallocating array of bit blocks
	free(array);

	exit(EXIT_SUCCESS);
}

//intialize bits in array of data structs to 0
void initialize_array(void)
{
	for (int i = 0; i < size; ++i)
	{
		array[i].bits = 0;
		pthread_mutex_init(&array[i].mutex, NULL);

	}
}

//free mutex
void free_mutex(void)
{
	for (int i = 0; i < size; ++i)
	{
		pthread_mutex_destroy(&array[i].mutex);
	}
}

//function to find the low square root of number
int find_root(int num)
{
	for (int i = 0; i < num; ++i)
	{
		if (((i+1) * (i+1)) > num)
		{
			root = i;
			break;
		}
	}
	return root;
}

//function to print the numbers that are marked as prime
void print_primes(void)
{
	printf("2\n");
	for (int i = 3; i <= limit; i+=2)
	{
		if (!((array[i/32].bits & (1 << (i%32)))))
		{
			printf("%d\n", i);
		}
	}
}

//sieve function using multi threading
void * sieve(void * sid)
{
	long start = (long) sid;

	for (long i = start; i <= root; i += (num_threads*2))
	{
		for (int j = (i*2); j <= limit; j += i)
		{
			if (!((array[j/32].bits & (1 << (j%32)))))
			{
				pthread_mutex_lock(&array[(j/32)].mutex);
				array[(j/32)].bits = array[(j/32)].bits | (1 << (j%32));
				pthread_mutex_unlock(&array[(j/32)].mutex);
			}
		}
	}
	pthread_exit(EXIT_SUCCESS);
}

