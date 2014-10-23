####################################################
# Makefile for project dedup 
# Created: Thu Oct 23 13:21:32 MDT 2014
#
# De-duplicates a column based file.
#    Copyright (C) 2014  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Written by Andrew Nisbet at Edmonton Public Library
# Rev: 
#      0.0 - Dev. 
####################################################
# Change comment below for appropriate server.
PRODUCTION_SERVER=eplapp.library.ualberta.ca
TEST_SERVER=edpl-t.library.ualberta.ca
USER=sirsi
REMOTE=~/Unicorn/Bincustom/
LOCAL=~/projects/dedup/
APP=dedup.pl
ARGS=-x

test:
	perl -c ${APP}
	cat test_key.txt | ./dedup.pl -fc1 -d
	cat test_key.txt | ./dedup.pl -fc2 -d
	cat test_key.txt | ./dedup.pl -fc3 -d
	# test dedup on column selection
	cat test_col.txt | ./dedup.pl -fc2 -d
	cat test_col.txt | ./dedup.pl -fc1 -d
	cat test_col.txt | ./dedup.pl -fc1,c2 -d
	# Test if dedup gets no valid range should print all lines.
	cat test_col.txt | ./dedup.pl -fc8 -d
	# Test duplicate examples
	cat test_dup.txt | ./dedup.pl -fc2 -d
	cat test_dup.txt | ./dedup.pl -fc1 -d
	cat test_dup.txt | ./dedup.pl -fc1,c2 -d
	# Order shouldn't matter.
	cat test_dup.txt | ./dedup.pl -fc2,c1 -d
	# Test malformed file, that is no columns to split. should print all lines none duplicated lines.
	cat test_dup_no_delimiter.txt | ./dedup.pl -fc1 -d
	cat test_dup_no_delimiter.txt | ./dedup.pl -fc2 -d
	cat test_dup_no_delimiter.txt | ./dedup.pl -fc1,c2 -d
	cat test_dup_no_delimiter.txt | ./dedup.pl -fc7 -d

production: test
	scp ${LOCAL}${APP} ${USER}@${PRODUCTION_SERVER}:${REMOTE}

put: test
	scp ${LOCAL}${APP} ${USER}@${TEST_SERVER}:${REMOTE}
	ssh ${USER}@${TEST_SERVER} '${REMOTE}${APP} ${ARGS}'