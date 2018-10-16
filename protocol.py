from collections import defaultdict


protocol_operation_argument = '''
    GeneName, r, --colsWanted 5
    refGene, g, --splicing_threshold 10 --transcript_function
    Gencode, r, --colsWanted 5
    cpgIslandExt, r, .
    cytoBand, r, .
    wgRna, r, .
    targetScanS, r, .
    tfbsConsSites, r, .
    genomicSuperDups, r, .
    gff3, r, .
    avsnp, f, .
    clinvar_20170905, f, .
    gwasCatalog, r, .
    generic, f, .
    1000g_EAS, f, .
    1000g_ALL, f, .
    esp6500si_all, f, .
    gnomad_gnome_exome_ALL_AF_AN, f, .
    gnomad_gnome_exome_EAS_AF_AN, f, .
    NovoDb_WES_2573, f, .
    Novo_WGS_568, f, .
    dbscsnv, f, .
    Spidex, f, .
    dbnsfp31a_interpro, f, .
    dbnsfp293apart, f, .
    phylopcadd, f, .
    gerp++gt2, f, .
    phylop46100way, f, .
    caddindel, f, .
    mcap, f, .
    revel, f, .
    
    phastConsElements46way, r, .
    dgvMerged, r, .
    encodeGm12878, r, .
    encodeH1hesc, r, .
    encodeHelas3, r, .
    encodeHepg2, r, .
    encodeHuvec, r, .
    encodeK562, r, .
'''

temp = protocol_operation_argument.strip().split('\n')

# protocol_maps = {'gnomad_gnome_exome_EAS_AF_AN': ['f', '.'], ...}
protocol_maps = dict([each.split(', ')[0].strip(), each.strip().split(', ')[1:]] for each in temp)


protocol = {}
common = '''
    GeneName refGene Gencode cpgIslandExt cytoBand wgRna targetScanS tfbsConsSites genomicSuperDups gff3
    avsnp clinvar_20170905 gwasCatalog generic 1000g_EAS 1000g_ALL esp6500si_all gnomad_gnome_exome_ALL_AF_AN gnomad_gnome_exome_EAS_AF_AN
    NovoDb_WES_2573 Novo_WGS_568 dbscsnv Spidex dbnsfp31a_interpro dbnsfp293apart'''.split()

protocol['snp'] = common + ' phylopcadd gerp++gt2 mcap revel'.split()
protocol['indel'] = common + 'phylop46100way caddindel gerp++gt2 mcap revel'.split()

protocol['sv'] = '''
    GeneName refGene Gencode cpgIslandExt cytoBand wgRna targetScanS phastConsElements46way tfbsConsSites genomicSuperDups
    dgvMerged gwasCatalog gff3 encodeGm12878 encodeH1hesc encodeHelas3 encodeHepg2 encodeHuvec encodeK562'''.split()


args4annovar = defaultdict(dict)

args4annovar['snp']['protocol'] = protocol['snp']
args4annovar['indel']['protocol'] = protocol['indel']
args4annovar['sv']['protocol'] = protocol['sv']

args4annovar['snp']['operation'] = [protocol_maps[p][0] for p in protocol['snp']]
args4annovar['indel']['operation'] = [protocol_maps[p][0] for p in protocol['indel']]
args4annovar['sv']['operation'] = [protocol_maps[p][0] for p in protocol['sv']]

args4annovar['snp']['argument'] = [protocol_maps[p][1] if protocol_maps[p][1] != '.' else '' for p in protocol['snp']]
args4annovar['indel']['argument'] = [protocol_maps[p][1] if protocol_maps[p][1] != '.' else '' for p in protocol['indel']]
args4annovar['sv']['argument'] = [protocol_maps[p][1] if protocol_maps[p][1] != '.' else '' for p in protocol['sv']]



if __name__ == '__main__':

    print 'SNP:', ','.join(protocol['snp'])
    print 'INDEL:', ','.join(protocol['indel'])
    print 'SV/CNV:', ','.join(protocol['sv'])

    print args4annovar['snp']
