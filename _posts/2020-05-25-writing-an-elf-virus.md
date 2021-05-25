---
layout: post
title: Writing an ELF Virus
description: How do you write an ELF virus?
summary: The mechanics and process of writing an ELF virus
comments: true
tags: [coding, malware, programming]
---

Recently I have been interested by the concept of computer viruses, and self-replicating programs more generally. There's something very compelling about the idea of a program that can move on it's own, spreading where you mgiht not intend it to. To fulfill that interest and learn more about viruses, I decided to write one.

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
3. Write some code to where it is now expecting it to be

In the case of viruses, that code we write just happens to be our own.


## Introduction to ELF

I wanted to write an ELF virus, one that would infect compiled programs. ELF, the Executable and Linkable Format is the standard that defines compiled programs for most open-source operating systems. 
