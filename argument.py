import os
import argparse


__version__ = 'v1.0'


parser = argparse.ArgumentParser(
    prog='pyannovar',
    description='\t\033[32mAnnotate vcf with ANNOVAR software\033[0m',
    formatter_class=argparse.RawDescriptionHelpFormatter,
    version=__version__)

parser.add_argument(
    '-i',
    '--infile',
    help='the input file(vcf, vcf.gz, gff...)',
    required=True)

parser.add_argument(
    '-p',
    '--protocol',
    help='specific the protocol to annotate, eg. -p refGene')

parser.add_argument(
    '-r',
    '--refversion',
    help='the version of reference genome, choose from %(choices)s [default=%(default)s]',
    default='b37',
    choices=['b37', 'hg19', 'hg38'])

parser.add_argument(
    '-t',
    '--type',
    help='the type of input file, choose from %(choices)s',
    choices=['snp', 'indel', 'sv'])

parser.add_argument(
    '-c',
    '--configfile',
    help='the config file for annovar')

parser.add_argument(
    '-th',
    '--thread',
    help='the thread to run annovar[default=%(default)s]',
    default=1)

parser.add_argument(
    '-test',
    help='just generate the commands but not execute it',
    action='store_true')

args = vars(parser.parse_args())
