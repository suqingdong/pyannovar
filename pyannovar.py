#!/usr/bin/env python
# -*- coding=utf-8 -*-
import os
import time
import textwrap

import utils
from argument import args

from protocol import args4annovar


class Annotate(object):

    def __init__(self):

        self.logger = utils.get_logger()
        self.config = utils.get_config(self.logger, args['configfile'])

        self.reffasta = self.config.get('genome', args['refversion'])

        self.__dict__.update(args)
        self.__dict__.update(dict(self.config.items('software')))

        self.CMD = ''
        self.START_TIME = time.time()

    def start(self):

        if not args['type']:
            if 'snp' in args['infile']:
                args['type'] = 'snp'
            elif 'indel' in args['infile']:
                args['type'] = 'indel'
            elif 'gff' in args['infile']:
                args['type'] = 'sv'
            else:
                self.logger.error('the type for your input file is unkown, please specific with argument -t')
                exit(1)

        if args['type'].lower() in ('snp', 'indel'):
            self.__dict__['samples'] = self.get_samples()
            self.logger.info('samples in vcf: {samples}'.format(**self.__dict__))
            self.annotate_vcf()
            self.reformat_result()
            if not args['protocol']:
                self.add_anno_by_name()
            self.revocer_alt_and_genotype()
            if not args['protocol']:
                self.add_pubmed_hgmd_hpa()
            self.remove_files()

        # total commands record
        cmd = 'annotate_{type}.sh'.format(**args)
        self.CMD = 'set -eo pipefail\n' + self.CMD

        with open(cmd, 'w') as out:
            out.write(self.CMD)

        self.logger.info('annotate done!')
        total_time = time.time() - self.START_TIME
        self.logger.info('total used time: {:.1f}s'.format(total_time))

    def annotate_vcf(self):

        self.__dict__['vcf'] = args['infile'].replace('_sn', '')

        if not os.path.exists(self.__dict__['vcf']):
            self.logger.error('vcf file not exists: {vcf}'.format(**self.__dict__))
            exit(1)

        if '_sn' in args['infile']:
            outprefix = args['infile'].strip('.vcf').strip('.vcf.gz') + '.annovar'
        else:
            sn_vcf = self.norm_vcf()
            self.__dict__['sn_vcf'] = sn_vcf
            outprefix = sn_vcf.strip('.vcf') + '.annovar'

        self.__dict__['outprefix'] = outprefix
        self.__dict__['outfinal'] = outprefix.replace('_sn', '')

        build_version = args['refversion']

        if args['refversion'] == 'b37':
            build_version = 'hg19'

        self.__dict__['build_version'] = build_version

        protocol_list = args4annovar[args['type']]['protocol']
        operation_list = args4annovar[args['type']]['operation']
        argument_list = args4annovar[args['type']]['argument']

        if args['protocol']:
            protocol = []
            operation = []
            argument = []
            protocols = args['protocol'].split(',')
            for each in protocols:
                if each not in protocol_list:
                    self.logger.error('invalid protocol "{}", please choose from: {}'.format(each, protocol_list))
                    exit(1)
                each_idx = protocol_list.index(each)
                protocol.append(each)
                operation.append(operation_list[each_idx])
                argument.append(argument_list[each_idx])
        else:
            protocol = protocol_list
            operation = operation_list
            argument = argument_list

        protocol = ','.join(protocol)
        operation = ','.join(operation)

        if any(argument):
            argument = "\\\n    -argument '{}' ".format(','.join(argument))
        else:
            argument = ''

        cmd = textwrap.dedent('''
            perl {annovar_dir}/table_annovar.pl \\
                {sn_vcf} \\
                {humandb} \\
                -buildver {build_version} \\
                -vcfinput \\
                -otherinfo \\
                -nastring . \\
                -remove \\
                --thread {thread} \\
                -protocol '{protocol}' \\
                -operation  '{operation}' {argument}\\
                -gff3dbfile {build_version}_rmsk.gff \\
                --genericdbfile 1000g_Chinese.txt \\
                -out {outprefix}
        ''').format(**dict(self.__dict__, **locals()))

        self.CMD += cmd

        self.logger.info('annotate vcf with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def norm_vcf(self):

        sn_vcf = args['infile'].replace('.vcf', '_sn.vcf').strip('.gz')

        cmd = textwrap.dedent('''
            {bcftools} norm \\
                 -m -both \\
                 -f {reffasta} \\
                 -o {sn_vcf} \\
                 {infile}
        ''').format(**dict(self.__dict__, **locals()))

        self.CMD += cmd

        self.logger.info('norm vcf with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

        return sn_vcf

    def get_samples(self):

        with utils.safe_open(self.__dict__['infile']) as f:
            for line in f:
                if line.startswith('#CHROM'):
                    linelist = line.strip().split('\t')
                    samplelist = linelist[linelist.index('FORMAT')+1:]
                    break

        return ','.join(samplelist)

    def reformat_result(self):

        cmd = textwrap.dedent('''
            perl {annovar_dir}/reformat_annovar.pl \\
                -v vcf4 -id {samples} \\
                {outprefix}.{build_version}_multianno.txt |
                sed '1s/.refGene//g' > {outprefix}.{build_version}_multianno.xls
        ''').format(**dict(self.__dict__, **locals()))

        self.CMD += cmd

        self.logger.info('reformat with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def add_anno_by_name(self):

        name_list = 'OMIM GWAS_Pubmed_pValue HGMD_ID_Diseasename HGMD_mutation GO_BP GO_CC GO_MF KEGG_PATHWAY PID_PATHWAY BIOCARTA_PATHWAY REACTOME_PATHWAY'.split()

        cmd = '\ncat {outprefix}.{build_version}_multianno.xls |\n'

        for name in name_list:
            cmd += '    perl {annovar_dir}/addAnn_byName_new.pl -annName %s |\n' % name

        cmd += "    sed '1s/CADD13_RawScore/CADD/; 1s/dbscSNV_ADA_SCORE/dbscSNV_SCORE/' > {outprefix}.{build_version}_multianno.mid.xls\n"

        cmd += "mv {outprefix}.{build_version}_multianno.mid.xls {outprefix}.{build_version}_multianno.xls\n"

        cmd = cmd.format(**self.__dict__)

        self.CMD += cmd

        self.logger.info('add annotation with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def revocer_alt_and_genotype(self):

        cmd = textwrap.dedent('''
            perl {annovar_dir}/get_ALT_and_Genotype_from_VCF_v4.6_v1.pl -vcf {vcf} -xls {outprefix}.{build_version}_multianno.xls
            mv -f {outprefix}.{build_version}_multianno.modified.xls {outfinal}.{build_version}_multianno.xls
        ''').format(**self.__dict__)

        self.CMD += cmd

        self.logger.info('recover alt and genotype with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def add_pubmed_hgmd_hpa(self):

        cmd = textwrap.dedent('''
            python {moduledir}/AddOMIM_HGMD/AddHGMD_OMIM_Priority_pipe4.6.py \\
                {outfinal}.{build_version}_multianno.xls \\
                {outfinal}.{build_version}_multianno.mid.xls \\
                {build_version}

            python {moduledir}/HPA.v15/annotatExpression_for_multiannofile.py \\
                -i {outfinal}.{build_version}_multianno.mid.xls \\
                -o {outfinal}.{build_version}_multianno.xls

            rm -f {outfinal}.{build_version}_multianno.mid.xls
        ''').format(**self.__dict__)

        self.CMD += cmd

        self.logger.info('add pubmed hgmd and hpa with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def remove_files(self):

        cmd = textwrap.dedent('''
            gzip -f {outfinal}.{build_version}_multianno.xls

            rm -f {outprefix}.* {sn_vcf}
        ''').format(**self.__dict__)

        self.CMD += cmd

        self.logger.info('remove files with command: {}'.format(cmd))

        if not args['test']:
            assert not os.system(cmd)

    def anno_gff(self):

        print 'to be added ...'




def main():

    annotate = Annotate()
    annotate.start()


if __name__ == "__main__":

    main()
