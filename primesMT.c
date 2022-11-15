// Alan Schaaf
// November 14, 2022

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

//intialize bits in array of data structs to 0 and init mutex, multi threaded!
void * init(void *);

//free mutex
void free_mutex(void);

//will change the bit located at the index passed as argument from 0 to 1
uint32_t set_bit(uint32_t, int);

//print the bit values
void print_bits(uint32_t);

//function that will mark a bit from array, based on the number that wish to mark
void set_bit_array(int);

//function that checks if a bit in array is already set
bool check_bit(int);

//function to print contents of bits in array for testing purposes
void print_array(void);

//function that intiates the sieve of eratosthenes
void mark_prime(void);

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
				fprintf(stderr, "VERBOSE ENABLED\n");
				is_verbose = true;
				break;
		}
	}
	//assigning values now that we have processed command line
	size = (limit/32) + 1;
	array = malloc(size * sizeof(BitBlocks_t));
	root = find_root(limit);
	//intializing all bits in array to 0
	initialize_array();
	threads = malloc(num_threads * sizeof(pthread_t));

	//using multi threading to initialize BitBlocks
	//for (long i = 0; i < num_threads; ++i)
	//{
	//	pthread_create(&threads[i], NULL, init, (void *) i);
	//}
	//for (long i  = 0; i < num_threads; ++i)
	//{
	//	pthread_join(threads[i], NULL);
	//}

	if (is_verbose)
	{
		fprintf(stderr, "threads: %d\nupperbound: %d\n", num_threads, limit);
	}

	for (long i = 0, start = 3; i < num_threads; ++i, start += 2)
	{
		if (is_verbose)
		{
			fprintf(stderr, "create thread: %ld\n", i+1);
		}
		pthread_create(&threads[i], NULL, sieve, (void *) start);
	}
	for (long i  = 0; i < num_threads; ++i)
	{
		if (is_verbose)
		{
			fprintf(stderr, "join thread: %ld\n", i+1);
		}
		pthread_join(threads[i], NULL);
	}

	//printf("limit: %d size: %d root: %d\n", limit, size, root);

	//mark_prime();
	//print_array(array, size);
	print_primes();

	//free memory
	free_mutex();
	free(threads);
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
	//initialize 0 and 1 to composite
	//set_bit_array(0);
	//set_bit_array(1);
}

//intialize bits in array of data structs to 0 and init mutex, multi threaded!
void * init(void * sid)
{
	long start = (long) sid;

	for (long i = start; i < size; i += (num_threads))
	{
		array[i].bits = 0;
		pthread_mutex_init(&array[i].mutex, NULL);
	}
	pthread_exit(EXIT_SUCCESS);
}

//free mutex
void free_mutex(void)
{
	for (int i = 0; i < size; ++i)
	{
		pthread_mutex_destroy(&array[i].mutex);
	}
}

//will change the bit located at the index passed as argument from 0 to 1
uint32_t set_bit(uint32_t data, int index)
{
	uint32_t mask = 0;
	mask = 1 << (index % 32);
	data = data | mask;	
	return data;
}

//print the bit values
void print_bits(uint32_t data)
{
	for (int i = 0; i < 32; ++i)
	{
		if (data & (1 << i))
			printf("1");
		else
			printf("0");
		if ((i+1) % 4 == 0)
			printf(" ");
	}
	printf("\n");
	
}

//function that will mark a bit from array, based on the number that wish to mark
void set_bit_array(int num)
{
	//int index = num / 32;
	//int bit_num = num % 32;
	//uint32_t mask = 0;
	
	//mask = 1 << (num%32);
	pthread_mutex_lock(&array[(num/32)].mutex);
	//array[(num/32)].bits = array[(num/32)].bits | mask;
	array[(num/32)].bits = array[(num/32)].bits | (1 << (num%32));
	pthread_mutex_unlock(&array[(num/32)].mutex);
}

//function that checks if a bit in array is already set
bool check_bit(int num)
{
	//int index = num / 32;
	//int bit_num = num % 32;

	if (array[num / 32].bits & (1 << (num % 32)))
		return true;
	else
		return false;
}

//function to print contents of bits in array for testing purposes
void print_array(void)
{
	for (int i = 0; i < size; ++i)
	{
		print_bits(array[i].bits);
	}
}

//function that intiates the sieve of eratosthenes
void mark_prime(void)
{
	for (int i = 2; i <= root; ++i)
	{
		//if number has not been marked composite
		if (check_bit(i) == false)
		{
			for (int j = i+i; j < limit; j += i)
			{
				set_bit_array(j);
			}
		}
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
		//if (check_bit(i) == false)
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
			//if (!(check_bit(j)))
			if (!((array[j/32].bits & (1 << (j%32)))))
			{
				//set_bit_array(j);
				pthread_mutex_lock(&array[(j/32)].mutex);
				array[(j/32)].bits = array[(j/32)].bits | (1 << (j%32));
				pthread_mutex_unlock(&array[(j/32)].mutex);
			}
		}
	}
	pthread_exit(EXIT_SUCCESS);
}

