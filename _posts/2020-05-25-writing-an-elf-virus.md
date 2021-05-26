---
layout: post
title: Writing an ELF Virus
description: The mechanics and process of writing an ELF executable virus
summary: The mechanics and process of writing an ELF executable virus
comments: true
tags: [malware, programming]
---

Recently I have been interested by the concept of computer viruses, and self-replicating programs more generally. There's something very compelling about the idea of a program that can move on it's own, spreading where you might not intend it to. To fulfill that interest and learn more about viruses, I decided to write one.

## What is a Virus?

Computer malware generally has been referred to as "viruses" for quite awhile, but as infosec gurus and antivirus companies would tell you, the term refers to a specific type of malware. Viruses are programs that can spread to other programs, infecting them with their own code. This is similar to but distinct from a worm, which is a program that can spread to other *computers*. 

![Worms spread to other computers, viruses spread to other files](/assets/img/virusvworm.jpg)


## Structure of a Virus

A virus is essentially two parts:

1. Infector
	- Search for other programs to infect
	- Set up programs for infection
	- Copy code into infected file
2. Payload

The infector is gives the virus its namesake, it infect other programs with its own code. It is also what makes programming one interesting, or at least a little confusing. In some sense, we can think of the infection steps as somewhat similar to ***recursion***.


1. Find an appropriate file to infect
2. Prepare the file to expect new code
3. Write some code where it is now expecting it 

In the case of viruses, that code we write just happens to be our own. When the infected file is run it goes to the code we prepared it to look for, runs it, spreads...


## Introduction to ELF

I wanted to write an ELF virus, one that would infect compiled programs. ELF, the Executable and Linkable Format, is the standard that defines these compiled programs. ELF is the standard for most open-source operating systems, and is used for both executables and libraries. 

ELF files have two main parts: segments, and sections. Segments define how to load important data into memory when running a program. Executables need them, but libraries don't. Sections define the information that's important for linking. They are needed by libraries, so that programs can be linked against them, but since they are used at link time and not runtime, sections are not needed by executables.

Since we are adding code, and not doing anything with linking, we're only going to be looking at segments in our virus. It's also important to know that these sections and segments are just headers, ranges in the file. Header structs point to where the segments and sections start and end, and these ranges often overlap.


## Overview

Infecting ELF files means that our code is going to have to be assembly. Otherwise, you'd have to convert between the intermediate form, C maybe, and the assembly when reading the code and writing code to the target files. So to simplify things we can just use assembly, and copy the bytes representing opcodes to target files, so that they load those opcodes and run them. Writing in assembly means that our code is the same as our data: the bytes we run are the bytes we copy.


Since we're writing assembly, we need an assembler. You can use whatever here, but a good assembler will support macros definitions and structs. I usually NASM, the Netwide Assembler, but ended up using FASM for this project. The first resources I looked at used it and is a slightly easier one to get started with.


## Development Environment

Whenever starting a project, a good development environment is key. It need not be a full IDE, but you should set up a convenient build process that lets you iterate and test new code quickly. Having a separate environment is often convenient for dependency and safety reasons, the latter being especially important for writing a virus.

One thing that virus authors didn't have at the time when viruses were big was easy access to virtualziation, to test their viruses without infecting their own files. Since we're not doing anything kernel or hardware related, just infecting software, we can use something they certainly didn't have: Docker. A basic container makes a quick and safe development environment. We can infect binaries in the container, and restart it when we want to clean the slate. Another strong tool in your arsenal is a good debugger. Maybe you felt I intentionally didn't put "gdb" and "good debugger" in the same previous sentence, but with the PEDA extension it is honestly a very decent tool. In all fairness, I only joke about gdb, it's a great tool and PEDA makes it much easier to work with. Having one is the quickest way to figure out why your code is not working and what the results should be.

Another tool that I highly recommend is strace. **s**trace traces **syscalls**, which are the main I/O and other requests the virus will make to the kernel to perform basic actions, like writing to and searching for files. strace will print the arguments and return values from these syscalls, which can give you a good sense of what a program is accessing and attempting to do. A nice feature is that it prints out the errno from a syscall that fails, which can be searched for in the manpage of that syscall to help you determine what isn't working. I used it a lot to follow syscalls, observing errors and also seeing which get called after conditional statements.


## Methodology 

Our methodology follows the same two steps from before, but the infector component is the most significant.

The virus searches for other programs in the current directory, opens them, and checks to see if they are eligible to be infected. We stick to ELF files, not previously infected, and only 64 bit, since 32 bit binaries aren't getting any younger.

Once files are opened, it maps them into memory using *mmap(2)*. This makes these eligibility checks easier. The last of these checks is to search for an segment we can use to store the virus code, and if we find that we change the beginning of that segment and the entrypoint of the program to the end of the file. Finally, we write the code to the end of the file, so that when it is run by a user the first instructions ran will be our virus code.


One last thing is an important choice. Viruses usually execute the original host binary after or before executing their spreading routines. One thing to always remember when writing one is that we are executing from an infected file, and that file is being executed for a reason, probably to do something the user is expecting. If our virus doesn't run the original code, it will quickly raise suspicion and be detected. Older viruses would sometimes not do this, effectively breaking the original program.


An infected file will be modified to run our virus first, and the virus will then go to the beginning of the legitimate program to minimize suspicion. To transfer control we use a conditional jump, from the end of the virus code to the original entrypoint, or OEP, of the original file. For reference, an infected file looks like this:

![An infected file: OEP, legitimate code, new EP in the virus code, then a jmp back to the OEP at the very end of the infected file.](/assets/img/virus_infected_file_diagram.png)


## Starting Out

The first generation of our virus is its own separate binary, but every one after that will be executing from the end of an infected file. It is important to use techniques that work in either context the code could be running in.

Keeping that in mind, let's get started with the basics, a simple ELF file to start. Any assembler will define where important segments begin, as well as what permissions they have. With fasm a simple binary looks like this:

```assembly

SYS_EXIT = 60

format ELF64 executable 3

segment readable executable

entry _start

_start:

mov rdi, 42
mov rax, SYS_EXIT
syscall

```

We define a macro, SYS_EXIT, to equal 60. This is basically the same as a preprocessor directive in C, a simple find/replace by the assembler. 60 is the syscall number for sys_exit on x64. A good reference for syscalls and their arguments is [this page](https://filippo.io/linux-syscall-table/). 

The program is defined as a 64 bit ELF executable, with one readable and executable segment. We define a label for the entrypoint, and write some x64 to call sys_exit with the first argument of 42. The syscall reference I've linked tells us that the first argument to the syscall in rdi is the status code to pass to exit(), in this case 42. 

We can compile the code on the command line with fasm:

```bash
$ fasm test.asm
flat assembler  version 1.73.27  (16384 kilobytes memory, x64)
2 passes, 136 bytes.

$ ./test
$ echo $?
42
$
```

$? tells us the exit code of the previous command, which was 42 as we expected. It works.


Using Docker is probably a post topic on its own, but to get started I just made a simple Dockerfile, an Ubuntu container with gdb, fasm, gdb-peda, and objdump installed. The CMD instruction and the end is set to \["/bin/bash"\]. A docker-compose script builds the container and makes it easy to run with the run command and the name of the service as set in the compose file. In the repository I named it "workshop":

```bash
$ docker-compose run workshop

...

root@a92cd2aef74c:/code#
```

If none of that made sense, don't worry about it. Just know that if you install Docker/docker-compose and run the same command in the repository on your computer, you will eventually get the same output.



## Step 1: Setup Code:

Here is some of the starter code:


```assembly



```




