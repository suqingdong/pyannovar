#!/bin/bash -eu
method="GATK"
thread="1"
optA=""
optV="vcf4"
optB="INDEL"
optT="SVType"
optAdd=""
optOnly=""
optRef="b37"
optCoding="F" #not ready
optNoncoding="F" #not ready
HumanDB="/ifs/TJPROJ3/DISEASE/Database/ANNOVAR/humandb/ANNOVAR_2017Jun01_V4.6"
Annovar="/PUBLIC/software/HUMAN/ANNOVAR_2017Jul16"
while getopts p:c:m:a:b:v:t:g:d:pj:z:r:efh opt
do
	case $opt in
	p)	
		thread="$OPTARG" #thread number for annovar
		;;
	m)
		method="$OPTARG" #tool for variant calling
		;;
	a)
		optA="$OPTARG" #somatic or germline
		;;
	b)
		optB="$OPTARG" #SNP or INDEL
		;;
        v)
                optV="$OPTARG" #format of infile
                ;;
        t)
                optT="$OPTARG" #SVType, only used for the title of SV annotation file(SVtype colname)
                ;;
	g)
		source "$OPTARG"
		;;
        d)
                HumanDB="$OPTARG" #specify another directory from which ANNOVAR will read database files
                ;;
	j)
		optAdd="$OPTARG" #add database, i.e. ANNOVAR should use both the default databases and the added databases for annotation
		;;
	z)
		optOnly="$OPTARG" #ANNOVAR only use databases specified by this argument for annotation
		;;
	r)
		optRef="$OPTARG" #The reference genome of VCF. b37 or hg19
		;;
	e)
		optCoding="T" #ANNOVAR only annotate exonic function, "T" or "F"
		;;
	f)
		optNoncoding="T" #ANNOVAR only annotate noncoding function, "T" or "F"
		;;
	h)
		#echo "Usage: $0 invalid option -$OPTARG" 
		echo "	Usage: $0 [-a 'somatic' or ''] [-b 'INDEL' or 'SNP'] [-v 'vcf4' or 'vcf4old'] [-t 'SVType', for SV/CNV, used as SVtype colname] <infile> <ID> [genericdbfile]"
		echo "		By default, the following database will be used for annotation: GeneName,refGene,Gencode,cytoBand,wgRna,targetScanS,tfbsConsSites,genomicSuperDups,gff3,avsnp144,clinvar_20150330,gwasCatalog,1000g2014oct_Chinese,1000g2015aug_eas,1000g2015aug_all,esp6500siv2_all,exac03_ALL_EAS,NovoDb_WES_SNP/INDEL,NovoDb_WGS_SNP/INDEL,sift,pp2hvar,pp2hdiv,mt,lrt,ma,fathmm,phyloP7way_vertebrate,phyloP20way_mammalian,siphy,gerp++gt2,caddgt10/caddindel"
		echo "	-b	variant type, SNP or INDEL[required, default is INDEL]"
		echo -e "\n	-j	If you want to add database, use -j, e.g. '$0 -j 1000g2014oct_sas <infile> <ID>'. ANNOVAR would add 1000g2014oct_sas to the default annotation list"
		echo -e "\n	-z	If you need ANNOVAR to only use a specified database for annotation, use -z, e.g. '$0 -z cadd <infile> <ID>'. ANNOVAR would only annotate cadd"
		echo -e "\n	-r	refrence genome of VCF file, b37 or hg19.[required, default is b37]"
		echo -e "\n	infile	input file, the filename should end with .vcf or .gff. [Required]"
		echo -e "\n	ID	sampleNames, seperated by ','. [Required]"
		echo -e "\n	genericdbfile	Custom-made databases, seperated by ','. The given files should be in directory /TJPROJ2/HUMAN/Database/ANNOVAR/humandb/. 1) By default, genericdbfile='1000g2014oct_Chinese.txt'. 2) If '-j generic' is used, genericdbfile='1000g2014oct_Chinese.txt,files you added. 3) If '-z generic' is used, genericdbfile='files you specified. [Optional]"
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

if [ $# -lt 2 ]
then 
	echo "Usage: $0 [-a 'somatic' or ''] [-b 'INDEL' or 'SNP'] [-v 'vcf4' or 'vcf4old'] [-t 'SVType', for SV/CNV, used as SVtype colname] <infile> <ID> [genericdbfile]"
	exit 1
fi

infile=$1
sampleID=$2
outDir=`dirname $infile`
if [ $# -eq 3 ]; then 
	genericdbfile=$3
fi

echo begin at: `date`

#set the default values for the arguments '-protocol' '--operation' '--argument'
Protocolfront="GeneName,refGene,Gencode,cpgIslandExt,cytoBand,wgRna,targetScanS,tfbsConsSites,genomicSuperDups,gff3,avsnp,clinvar_20170905,gwasCatalog,generic,1000g_EAS,1000g_ALL,esp6500si_all,gnomad_gnome_exome_ALL_AF_AN,gnomad_gnome_exome_EAS_AF_AN"
genericdbfiles="1000g_Chinese.txt"
if [ "$optB"x == "SNP"x ]; then
	Protocol=${Protocolfront}",NovoDb_WES_2573,Novo_WGS_568,dbscsnv,Spidex,dbnsfp31a_interpro,dbnsfp293apart,phylopcadd,gerp++gt2,mcap,revel"
	Operation="r,g,r,r,r,r,r,r,r,r,f,f,r,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f"
	Arguments="--colsWanted 5,--splicing_threshold 10 --transcript_function,--colsWanted 5,,,,,,,,,,,,,,,,,,,,,,,,,,"
else
	Protocol=${Protocolfront}",NovoDb_WES_2573,Novo_WGS_568,dbscsnv,Spidex,dbnsfp31a_interpro,dbnsfp293apart,phylop46100way,caddindel,gerp++gt2,mcap,revel"
	Operation="r,g,r,r,r,r,r,r,r,r,f,f,r,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f"
	Arguments="--colsWanted 5,--splicing_threshold 10 --transcript_function,--colsWanted 5,,,,,,,,,,,,,,,,,,,,,,,,,,,"
fi

#get operation for each database
declare -A database_operation
declare -A database_argument
while read databaseName operationClass argums
do
	#echo $databaseName"  "$operationClass"  "$argums
	database_operation[$databaseName]=$operationClass
	if [ "$argums"x = "N"x ]; then
		argums=""
	fi
	database_argument[$databaseName]=$argums
done</PUBLIC/software/HUMAN/ANNOVAR_2015Mar22/protocol_operation_argument.table

#set new values for the arguments '-protocol' '--operation' '--argument'
AddProtocol=""
AddOperation=""
AddArguments=""
OnlyProtocol=""
OnlyOperation=""
OnlyArguments=""
if [ "$optAdd"x != ""x ]; then
	echo "Add databases: "$optAdd
	AddProtocol=${Protocol}
	AddOperation=${Operation}
	AddArguments=${Arguments}
	i=1  
	while((1==1))
	do
		split=`echo $optAdd |cut -d "," -f$i`
		echo $split
		#optAdd=${optAdd / // }
		if [ "$split" != "" ]; then
			((i++))
			if [ "$split" == "generic" ]; then
				j=1
				while((1==1))
				do
					added_genericdbfile=`echo $genericdbfile |cut -d "," -f$j`
					echo $added_genericdbfile
					if [ "$added_genericdbfile" != "" ]; then
						((j++))
						if [ "$added_genericdbfile" != "1000g2014oct_Chinese.txt" ]; then
							genericdbfiles=${genericdbfiles}","$added_genericdbfile
							AddProtocol=${AddProtocol}",generic"
							AddOperation=${AddOperation}","${database_operation["generic"]}
							AddArguments=${AddArguments}","${database_argument["generic"]}
						fi
						if [[ "$genericdbfile" =~ "," ]]; then
							echo ""
							#do nothing
						else
							#only add one generic database
							break
						fi
					else
						break
					fi
				done
			else
				AddProtocol=${AddProtocol}","$split
				AddOperation=${AddOperation}","${database_operation["$split"]}
				AddArguments=${AddArguments}","${database_argument["$split"]}
			fi
			echo $AddProtocol"  "$AddOperation"  "$AddArguments"  "$genericdbfiles
			if [[ "$optAdd" =~ "," ]]; then
				echo ""
				#do nothing
			else
				 #only add one database
				break
			fi
		else
			break
		fi
	done
elif [ "$optOnly"x != ""x ]; then
	genericdbfiles=""
	echo "Only use databases: "$optOnly
	i=1
	while((1==1))
	do
		split=`echo $optOnly |cut -d "," -f$i`
		echo $split
		if [ "$split" != "" ]; then
			((i++))
			if [ $i -eq 2 ]; then #the first database
				if [ "$split" == "generic" ]; then #the first database is generic
					j=1
					while((1==1))
					do
						added_genericdbfile=`echo $genericdbfile |cut -d "," -f$j`
						echo $added_genericdbfile
						if [ "$added_genericdbfile" != "" ]; then
							((j++))
							if [ $j -eq 2 ]; then #the first genericdbfile
								genericdbfiles=$added_genericdbfile
								OnlyProtocol="generic"
								OnlyOperation=${database_operation["generic"]}
								OnlyArguments=${database_argument["generic"]}
							else
								genericdbfiles=${genericdbfiles}","$added_genericdbfile
								OnlyProtocol=${OnlyProtocol}",generic"
								OnlyOperation=${OnlyOperation}","${database_operation["generic"]}
								OnlyArguments=${OnlyArguments}","${database_argument["generic"]}
							fi
							if [[ "$genericdbfile" =~ "," ]]; then
								echo ""
								#do nothing
							else
								#only one generic database
								break
							fi
						else
							break
						fi
					done
				else #the first database is not generic
					OnlyProtocol=$split
					OnlyOperation=${database_operation["$split"]}
					OnlyArguments=${database_argument["$split"]}
				fi
			else
				if [ "$split" == "generic" ]; then #the database is generic
					j=1
					while((1==1))
					do
						added_genericdbfile=`echo $genericdbfile |cut -d "," -f$j`
						echo $added_genericdbfile
						if [ "$added_genericdbfile" != "" ]; then
							((j++))
							if [ $j -eq 2 ]; then #the first genericdbfile
								genericdbfiles=$added_genericdbfile
							else
								genericdbfiles=${genericdbfiles}","$added_genericdbfile
							fi
							OnlyProtocol=${OnlyProtocol}",generic"
							OnlyOperation=${OnlyOperation}","${database_operation["generic"]}
							OnlyArguments=${OnlyArguments}","${database_argument["generic"]}
							if [[ "$genericdbfile" =~ "," ]]; then
								echo ""
								#do nothing
							else
								#only one generic database
								break
							fi
						else
							break
						fi
					done
				else
					OnlyProtocol=${OnlyProtocol}","$split
					OnlyOperation=${OnlyOperation}","${database_operation["$split"]}
					OnlyArguments=${OnlyArguments}","${database_argument["$split"]}
				fi
			fi
			echo $OnlyProtocol"  "$OnlyOperation"  "$OnlyArguments"  "$genericdbfiles
			if [[ "$optOnly" =~ "," ]]; then
				echo ""
				#do nothing
			else
				#only use one database
				break
			fi
		else
			break
		fi
	done
fi

echo ">>> annotate ..."

mkdir -p $outDir


if [[ "$infile" =~ ".vcf" ]]; then
	if [[ "$infile" =~ "_sn.vcf.gz" ]]; then
		filename=${infile/_sn.vcf.gz/}
		infile=${filename}_sn.vcf.gz
	elif [[ "$infile" =~ "_sn.vcf" ]]; then
		filename=${infile/_sn.vcf/}
		infile=${filename}_sn.vcf
	elif [[ "$infile" =~ ".vcf.gz" ]]; then
		filename=${infile/.vcf.gz/}
		echo ">>>use bcftools norm to pre-process the infile"
		bcftools norm -m -both -o ${filename}_s.vcf $filename.vcf.gz
		if [ "$optRef"x == "hg19"x ]; then
			ref_file="/PUBLIC/database/HUMAN/genome/human/hg19/bwa_index/hg19.fa"
		else
			ref_file="/PUBLIC/database/HUMAN/genome/Human/human_g1k_v37_decoy.fasta"
		fi
		bcftools norm -f ${ref_file} -o ${filename}_sn.vcf ${filename}_s.vcf
		infile=${filename}_sn.vcf
		echo "bcftools norm -m -both -o ${filename}_s.vcf $filename.vcf.gz"
		echo "bcftools norm -f ${ref_file} -o ${filename}_sn.vcf ${filename}_s.vcf"
		rm ${filename}_s.vcf
	elif [[ "$infile" =~ ".vcf" ]]; then
		filename=${infile/.vcf/}
		echo ">>>use bcftools norm to pre-process the infile"
		bcftools norm -m -both -o ${filename}_s.vcf $filename.vcf
		if [ "$optRef"x == "hg19"x ]; then
			ref_file="/PUBLIC/database/HUMAN/genome/human/hg19/bwa_index/hg19.fa"
		else
			ref_file="/PUBLIC/database/HUMAN/genome/Human/human_g1k_v37_decoy.fasta"
		fi
		bcftools norm -f ${ref_file} -o ${filename}_sn.vcf ${filename}_s.vcf
		infile=${filename}_sn.vcf
		echo "bcftools norm -m -both -o ${filename}_s.vcf $filename.vcf"
		echo "bcftools norm -f ${ref_file} -o ${filename}_sn.vcf ${filename}_s.vcf"
		rm ${filename}_s.vcf
	fi
	
	basename=${filename}_sn
	annovarOut=$basename.annovar.hg19_multianno
	reformatedOut=$basename.reformated

#	if [ ! -f "$reformatedOut.vcf" ];then
		if [ "$genericdbfiles"x != ""x ]; then
			#create a hash, key: generic*, value: database_name. This hash will be used to replace the generic* with database_name in the title line.
			#Note: database_name is the prefix of the genericdbfile filename. For example, dbSNP142_AF is the database_name for 'dbSNP142_AF.txt'.
			echo $genericdbfiles
			echo "print... genericdbfile: default_colname  new_colname"
			declare -A generic_colname
			i=1
			while((1==1))
			do
				added_genericdbfile=`echo $genericdbfiles |cut -d "," -f$i`
				echo $added_genericdbfile
				if [ "$added_genericdbfile" != "" ]; then
					((i++))
					colname=${added_genericdbfile%.txt}
					if [ $i -eq 2 ]; then #the first genericdbfile
						generic_colname["generic"]=$colname
						echo "generic  "$colname
					else
						xuhao=$[$i-1]
						generic_colname["generic"${xuhao}]=$colname
						echo "generic"${xuhao}"  "$colname
					fi
					if [[ "$genericdbfiles" =~ "," ]]; then
						echo ""
						#do nothing
					else
						#only one generic database
						break
					fi
				else
					break
				fi
			done

			genericdbfiles="--genericdbfile "$genericdbfiles
		fi
		
		if [ "$optAdd"x != ""x ]; then
			if [ $thread -gt 1 ]; then
				echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -thread $thread -otherinfo -nastring . -protocol $AddProtocol --operation $AddOperation --gff3dbfile hg19_rmsk.gff $genericdbfiles --vcfinput --argument '$AddArguments' --outfile $basename.annovar" >$outDir/Annotate_Add_${optB}.sh
				. $outDir/Annotate_Add_${optB}.sh
			else
				echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -otherinfo -nastring . -protocol $AddProtocol --operation $AddOperation --gff3dbfile hg19_rmsk.gff $genericdbfiles --vcfinput --argument '$AddArguments' --outfile $basename.annovar" >$outDir/Annotate_Add_${optB}.sh
				. $outDir/Annotate_Add_${optB}.sh
			fi
		elif [ "$optOnly"x != ""x ]; then
			gff3_flag=""
			if [[ "$OnlyProtocol" =~ "gff3" ]]; then
				gff3_flag="--gff3dbfile hg19_rmsk.gff"
			fi
			if [ "$OnlyArguments"x != ""x ]; then
				if [ $thread -gt 1 ]; then
					echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -thread $thread -otherinfo -nastring . -protocol $OnlyProtocol --operation $OnlyOperation $gff3_flag $genericdbfiles --vcfinput --argument '$OnlyArguments' --outfile $basename.annovar" >$outDir/Annotate_Only_${optB}.sh
				else
					echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -otherinfo -nastring . -protocol $OnlyProtocol --operation $OnlyOperation $gff3_flag $genericdbfiles --vcfinput --argument '$OnlyArguments' --outfile $basename.annovar" >$outDir/Annotate_Only_${optB}.sh
				fi
			else	#only one database
				if [ $thread -gt 1 ]; then
					echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -thread $thread -otherinfo -nastring . -protocol $OnlyProtocol --operation $OnlyOperation $gff3_flag $genericdbfiles --vcfinput --outfile $basename.annovar" >$outDir/Annotate_Only_${optB}.sh
				else
					echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -otherinfo -nastring . -protocol $OnlyProtocol --operation $OnlyOperation $gff3_flag $genericdbfiles --vcfinput --outfile $basename.annovar" >$outDir/Annotate_Only_${optB}.sh
				fi
			fi
			. $outDir/Annotate_Only_${optB}.sh
		else
			if [ $thread -gt 1 ]; then
				echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -thread $thread -otherinfo -nastring . -remove -protocol $Protocol -operation $Operation -gff3dbfile hg19_rmsk.gff $genericdbfiles -vcfinput -argument '$Arguments' -out $basename.annovar" >$outDir/Annotate_default_${optB}.sh
			else
				echo -e "$Annovar/table_annovar.pl $infile $HumanDB -buildver hg19 -otherinfo -nastring . -remove -protocol $Protocol -operation $Operation -gff3dbfile hg19_rmsk.gff $genericdbfiles -vcfinput -argument '$Arguments' -out $basename.annovar" >$outDir/Annotate_default_${optB}.sh
			fi
			echo "script1: sh $outDir/Annotate_default_${optB}.sh"
			. $outDir/Annotate_default_${optB}.sh
		fi
		rm $annovarOut.vcf
		
		#replace the generic* with database_name in the reformatedOut.vcf. replace the generic* with database_name in the title line of *annovar.hg19_multianno.txt.
		echo "print... replace the generic* with database_name in the reformatedOut.vcf. replace the generic* with database_name in the title line of *annovar.hg19_multianno.txt."
		for ori_colname in ${!generic_colname[@]}
		do
			colname=${generic_colname[$ori_colname]}
			echo $ori_colname"  "$colname
			sed -i "1,1s/${ori_colname}\t/${colname}\t/g" $annovarOut.txt
		done
		

	GeneName_flag="F"
	if [ "$optOnly"x = ""x ]; then
		GeneName_flag="T"
	elif [[ "$optOnly" =~ "GeneName" ]]; then
		GeneName_flag="T"
	fi

	## refomrat the ouput table_variants file, mainly for the otherinfo field
	if [[ "$optA" =~ "somatic" ]]; then
		$Annovar/reformat_annovar.pl $annovarOut.txt -v $optV -id ${sampleID} | sed '1,1s/.refGene//g' > $reformatedOut.xls
		#$Annovar/pathway_annotation.py $reformatedOut.xls KEGG,PID,BIOCARTA,REACTOME,GO_BP,GO_CC,GO_MF > $basename.pathway.xls
	else
		echo "script2: $Annovar/reformat_annovar.pl $annovarOut.txt -v $optV -id $sampleID | sed '1,1s/.refGene//g' > $reformatedOut.xls"
		$Annovar/reformat_annovar.pl $annovarOut.txt -v $optV -id $sampleID | sed '1,1s/.refGene//g' > $reformatedOut.xls
	fi
	
	rm -f $basename.annovar.*
	echo "script3: addAnn_byName_new.pl GWAS_Pubmed_pValue HGMD_ID_Diseasename HGMD_mutation GO_BP GO_CC GO_MF KEGG_PATHWAY PID_PATHWAY BIOCARTA_PATHWAY REACTOME_PATHWAY" 
	if [ "$GeneName_flag"x = "T"x ]; then
		$Annovar/addAnn_byName_new.pl -annName OMIM $reformatedOut.xls \
		  | $Annovar/addAnn_byName_new.pl -annName GWAS_Pubmed_pValue \
		  | $Annovar/addAnn_byName_new.pl -annName HGMD_ID_Diseasename \
		  | $Annovar/addAnn_byName_new.pl -annName HGMD_mutation \
                  | $Annovar/addAnn_byName_new.pl -annName GO_BP \
		  | $Annovar/addAnn_byName_new.pl -annName GO_CC \
		  | $Annovar/addAnn_byName_new.pl -annName GO_MF \
		  | $Annovar/addAnn_byName_new.pl -annName KEGG_PATHWAY \
		  | $Annovar/addAnn_byName_new.pl -annName PID_PATHWAY \
		  | $Annovar/addAnn_byName_new.pl -annName BIOCARTA_PATHWAY \
		  | $Annovar/addAnn_byName_new.pl -annName REACTOME_PATHWAY \
		  > $annovarOut.xls
		## stat
		rm $reformatedOut.xls
	else
		mv $reformatedOut.xls $annovarOut.xls
	fi
    	perl $Annovar/get_ALT_and_Genotype_from_VCF_v4.6_v1.pl -vcf ${filename}.vcf.gz -xls $annovarOut.xls
	echo "script4: $Annovar/get_ALT_and_Genotype_from_VCF_v4.6_v1.pl -vcf ${filename}.vcf.gz -xls $annovarOut.xls"
	mv $annovarOut.xls $annovarOut.xls.bak
	mv $annovarOut.modified.xls $annovarOut.xls
	sed -i '1,1s/CADD13_RawScore/CADD/;1,1s/dbscSNV_ADA_SCORE/dbscSNV_SCORE/' $annovarOut.xls
	echo "mv $annovarOut.xls $annovarOut.xls.bak"
	echo "mv $annovarOut.modified.xls $annovarOut.xls"
	echo "sed -i '1,1s/CADD13_RawScore/CADD/;1,1s/dbscSNV_ADA_SCORE/dbscSNV_SCORE/' $annovarOut.xls"
#bgzip $infile
elif [[ "$infile" =~ ".gff" ]]; then

	##python $PIPELINE/var/annotate.gff.py $outDir/$sampleID.$method.ann.txt $infile
	###"SVID" "SVType must be in column9;
	basename=${infile/.gff/}
	awk -F"\t" -v OFS="\t" '{print $1,$4,$5,"0","0",$9;}' $infile > $infile.avinput
	if [ $thread -gt 1 ]; then
		$Annovar/table_annovar.pl $infile.avinput $HumanDB -buildver hg19 -thread $thread -otherinfo -remove -nastring . \
			-protocol GeneName,refGene,Gencode,cpgIslandExt,cytoBand,wgRna,targetScanS,phastConsElements46way,tfbsConsSites,genomicSuperDups,dgvMerged,gwasCatalog,gff3,encodeGm12878,encodeH1hesc,encodeHelas3,encodeHepg2,encodeHuvec,encodeK562 \
			-operation r,g,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r \
			--gff3dbfile hg19_rmsk.gff \
			--argument '--colsWanted 5,--splicing_threshold 10 --transcript_function,--colsWanted 5,,,,,,,,,,,,,,,,' \
			--outfile $basename
	else
		$Annovar/table_annovar.pl $infile.avinput $HumanDB -buildver hg19 -otherinfo -remove -nastring . \
			-protocol GeneName,refGene,Gencode,cpgIslandExt,cytoBand,wgRna,targetScanS,phastConsElements46way,tfbsConsSites,genomicSuperDups,dgvMerged,gwasCatalog,gff3,encodeGm12878,encodeH1hesc,encodeHelas3,encodeHepg2,encodeHuvec,encodeK562 \
			-operation r,g,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r \
			--gff3dbfile hg19_rmsk.gff \
			--argument '--colsWanted 5,--splicing_threshold 10 --transcript_function,--colsWanted 5,,,,,,,,,,,,,,,,' \
			--outfile $basename
	fi
	$Annovar/multianno.reformat.pl $basename.hg19_multianno.txt | sed '1,1s/gff3/Repeat/' | sed '1,1s/.refGene//g'| awk -F '\t' -v OFS="\t" '{$4=$5=$10=$11=null;print}' | sed 's/\t\t\t/\t/g' > $basename.hg19_multianno.xls
#	var_sv_putative.fusion.gene.pl $basename.ann.xls > $basename.ann.fusionGene.xls

	## all gene 
	$Annovar/cnv.geneInfo.pl -t $optT $basename.hg19_multianno.xls \
	  |$Annovar/addAnn_byName_new.pl -annName OMIM  \
	  | $Annovar/addAnn_byName_new.pl -annName GO_BP \
	  | $Annovar/addAnn_byName_new.pl -annName GO_CC \
	  | $Annovar/addAnn_byName_new.pl -annName GO_MF \
	  | $Annovar/addAnn_byName_new.pl -annName KEGG_PATHWAY \
	  | $Annovar/addAnn_byName_new.pl -annName PID_PATHWAY \
	  | $Annovar/addAnn_byName_new.pl -annName BIOCARTA_PATHWAY \
	  | $Annovar/addAnn_byName_new.pl -annName REACTOME_PATHWAY \
	  > $basename.geneInfo.xls
	## only fusion genes
#	$Annovar/addAnn_byName.pl -annName OMIM $basename.ann.fusionGene.xls \
#	  | $Annovar/addAnn_byName.pl -annName CancerGene \
#	  | $Annovar/addAnn_byName.pl -annName BertVogelstein125 -annFile /PUBLIC/database/HUMAN/AnnotationDB/Cancer/Gene.manual.BertVogelstein125 \
#	  | $Annovar/addAnn_byName.pl -annName Predisposition -annFile /PUBLIC/database/HUMAN/AnnotationDB/Cancer/cancer_gene_predisposition.slim.txt \
#	  | $Annovar/addAnn_byName.pl -annName DriverCNA -annFile /PUBLIC/database/HUMAN/AnnotationDB/Cancer/cancer_gene_cnv.slim.txt \
#	  | $Annovar/addAnn_byName.pl -annName Rearrangement -annFile /PUBLIC/database/HUMAN/AnnotationDB/Cancer/cancer_gene_rearrangment.slim.txt \
#	  | $Annovar/addAnn_byName.pl -annName GO_BP \
#	  | $Annovar/addAnn_byName.pl -annName GO_CC \
#	  | $Annovar/addAnn_byName.pl -annName GO_MF \
#	  | $Annovar/addAnn_byName.pl -annName KEGG_PATHWAY \
#	  | $Annovar/addAnn_byName.pl -annName PID_PATHWA \
#	  | $Annovar/addAnn_byName.pl -annName BIOCARTA_PATHWAY \
#	  | $Annovar/addAnn_byName.pl -annName REACTOME_PATHWAY \
#	  > $basname.annfusionGene.geneInfo.xls
	## only fusion genes

	rm -f $infile.avinput $basename.hg19_multianno.txt $basename.*.invalid_input 2>/dev/null
fi

echo "*** Finished annotating variants ***"