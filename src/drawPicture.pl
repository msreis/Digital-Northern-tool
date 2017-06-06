#!/usr/bin/perl -w

# CGI para gerar uma figura de Digital Northern
#
# M.Reis, 24.05.06

use strict;
use GD;
use CGI;

my $GAMMA_CORRECTION = 0.85;

my $imageName = "/home/mreis/public_html/unipaper/drawPicture/tmp/";
my $imageAddress = "http://powerswingle.centrodecitricultura.br/~mreis/unipaper/drawPicture/tmp/";


my $buffer = "";

if ($ENV{REQUEST_METHOD} eq 'POST'){
    read(STDIN, $buffer, $ENV{CONTENT_LENGTH});
}
else{
    $buffer = $ENV{QUERY_STRING};
}

my @pares = split(/&/, $buffer);

my %conteudo = ();

foreach my $par (@pares){

    my ($campo, $valor) = split("=", $par);

    $valor =~ s/\+/ /g;

    # convertendo os caracteres em hexadecimal para sua representaçao ASCII
    $valor =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;

    $conteudo{$campo} = $valor;
}


my @libsMatrix = [];
my @stringArray = [];
# my $numOfGenes = $conteudo{'numOfGenes'};
my $numOfGenes = 0;
my $numOfLibs = $conteudo{'numOfLibs'};
my $COLOR = $conteudo{'color'};
my $maxStringLength = 0;
my $maxRelativeAbundance = 1;

foreach my $linha (split "\n", $conteudo{'libsMatrix'}){
	chomp($linha);
	if($linha =~ /(^\S+\s+.*)\s+\[(.*)\]/){
                $libsMatrix[$numOfGenes] = [split('\s',$1)];
		$stringArray[$numOfGenes] = $2;
		if (length($stringArray[$numOfGenes]) > $maxStringLength){
			$maxStringLength = length($stringArray[$numOfGenes]);
		}
		$numOfGenes++;
        }
}

# gerando a figura

my $columnSize = (20 * $numOfGenes) + 130;
my $rowSize = 280 + (50 * $numOfLibs) + (6 * $maxStringLength);

my $gd = new GD::Image($rowSize, $columnSize);

# aloca algumas cores
my $white = $gd->colorAllocate(255,255,255);
my $black = $gd->colorAllocate(0,0,0);
my $red = $gd->colorAllocate(255,0,0);
my $yellow = $gd->colorAllocate(255,255,0);
my $grey = $gd->colorAllocate(128,128,128);
my $green = $gd->colorAllocate(0,255,0);

for(my $i=1; $i <= $numOfLibs; $i++){
	$gd->stringUp(gdLargeFont,($i*50) + 70, 35, "L0$i",$black);
}

my $axisY = 0;

for(my $j=0; $j < $numOfGenes; $j++){
        for(my $i=1; $i <= $numOfLibs; $i++){
                if ($libsMatrix[$j]->[$i-1] > $maxRelativeAbundance){
                        $maxRelativeAbundance = $libsMatrix[$j]->[$i-1];
                }
        }
}


#
# calcula a distancia euclidiana, montando a matriz de distacias;
#
# dessa forma, eh possivel calcular a clusterizacao aglomerativa.
#

my @euclidianDistance = [];

for(my $j=0; $j < $numOfGenes; $j++){

	for(my $k=0; $k < $numOfGenes; $k++){

	        my $currentSum = 0;

	        for(my $i=1; $i <= $numOfLibs; $i++){
			$currentSum = $currentSum + (($libsMatrix[$j]->[$i-1] - $libsMatrix[$k]->[$i-1]) ** 2) ;
		}

		$euclidianDistance[$j]->[$k] = sqrt($currentSum);

	}
}

#
# a funcao comentada abaixo imprime, para testes, a matriz de distancias
#
#
#open(TESTE,">/tmp/teste.txt");
#for(my $j=0; $j < $numOfGenes; $j++){
#        for(my $k=0; $k < $j; $k++){
#		printf TESTE  "%4.4f ", $euclidianDistance[$j]->[$k];
#	}
#	print TESTE "\n";
#}
#close(TESTE);
#

#
# calcula a clusterizacao aglomerativa, utilizando a matriz de distancias,
# armazenando o resultado da clusterizacao em uma arvore.
#
# criterio de merge dos clusters: a distancia minima entre os elementos de 
# um dado cluster ("single linkage clustering")
#
# estrutura da arvore: (((A,D),B),C))
#

my %agglomerativeSets = ();
my $remainingElements = 0;

for(my $j=0; $j < $numOfGenes; $j++){
        $agglomerativeSets{$j} = 0;
        $remainingElements++;
}

my $tree = "";

my %subTree = [];

my $setNumber = 1;

do{
	my $minX = 0;
	my $minY = 0;
	my $minDistance = 999999;

	for(my $j=0; $j < $numOfGenes; $j++){
       		for(my $k=0; $k < $j; $k++){

			# Caso tratar-se da menor distancia e nao pertencerem ao mesmo set
			#
			if(($minDistance > $euclidianDistance[$j]->[$k]) and
			   (($agglomerativeSets{$j} != $agglomerativeSets{$k}) or
			    (($agglomerativeSets{$j} == 0) and ($agglomerativeSets{$k} == 0)))){
				
				$minX = $j;
				$minY = $k;
				$minDistance = $euclidianDistance[$j]->[$k];

			}
		}
	}

	if(($agglomerativeSets{$minX} == 0) and ($agglomerativeSets{$minY} == 0)){
		$agglomerativeSets{$minX} = $setNumber;
		$agglomerativeSets{$minY} = $setNumber;
		$subTree{$setNumber} = "($minX,$minY)";	
		$tree = $subTree{$setNumber};
		$setNumber++;
	}
	elsif(($agglomerativeSets{$minX} == 0) and ($agglomerativeSets{$minY} != 0)){
		$agglomerativeSets{$minX} = $agglomerativeSets{$minY};
		$subTree{$agglomerativeSets{$minY}} = "($subTree{$agglomerativeSets{$minY}},$minX)";
		$tree = $subTree{$agglomerativeSets{$minY}};
	}
        elsif(($agglomerativeSets{$minX} != 0) and ($agglomerativeSets{$minY} == 0)){
                $agglomerativeSets{$minY} = $agglomerativeSets{$minX};
		$subTree{$agglomerativeSets{$minX}} = "($subTree{$agglomerativeSets{$minX}},$minY)";
		$tree = $subTree{$agglomerativeSets{$minX}};
        }
	else{
		my $valueMinY = $agglomerativeSets{$minY};
		$subTree{$agglomerativeSets{$minX}} = "($subTree{$agglomerativeSets{$minX}},$subTree{$valueMinY})";
		$tree = $subTree{$agglomerativeSets{$minX}};
		foreach my $k (sort keys(%agglomerativeSets)){
			if($agglomerativeSets{$k} == $valueMinY){
				$agglomerativeSets{$k} = $agglomerativeSets{$minX};
			}
		}	
	}

# depuracao dos passos da clusterizacao aglomerativa
#
#	foreach my $k (sort keys(%agglomerativeSets)){
#		print TESTE "$k -> $agglomerativeSets{$k}; ";
#	}

	$remainingElements--;

}while($remainingElements > 1);

#
# imprime a arvore binaria na figura, em forma de dendograma
#

# sub printTree($tree, 0);


#
# imprime, de maneira ordenada, os genes
#
#

for(my $j=0; $j < $numOfGenes; $j++){

	for(my $i=1; $i <= $numOfLibs; $i++){

		my $degrade = int(($libsMatrix[$j]->[$i-1] / $maxRelativeAbundance) * 225 * $GAMMA_CORRECTION) + 25;

		if($libsMatrix[$j]->[$i-1] == 0){
			$degrade = 0;
		}

		if($degrade > 255){
			$degrade = 255;
		}

		if ($COLOR eq 'B'){
			my $currentColor = $gd->colorAllocate(0,0,$degrade);
			$gd->rectangle(($i * 50)+50,($axisY * 20) + 50,($i * 50) + 100,($axisY * 20)+70, $currentColor);
			$gd->fill(($i * 50) + 55,($axisY * 20) + 55, $currentColor);
		}
        	elsif ($COLOR eq 'R'){
                	my $currentColor = $gd->colorAllocate($degrade,0,0);
			$gd->rectangle(($i * 50)+50,($axisY * 20) + 50,($i * 50) + 100,($axisY * 20)+70, $currentColor);
			$gd->fill(($i * 50) + 55,($axisY * 20) + 55, $currentColor);
 		}
		elsif ($COLOR eq 'G'){
                	my $currentColor = $gd->colorAllocate(0,$degrade,0);
			$gd->rectangle(($i * 50)+50,($axisY * 20) + 50,($i * 50) + 100,($axisY * 20)+70, $currentColor);
			$gd->fill(($i * 50) + 55,($axisY * 20) + 55, $currentColor);
		}
		else{
			my $currentColor = $gd->colorAllocate($degrade-20,$degrade-20,$degrade-20);
			$gd->rectangle(($i * 50)+50,($axisY * 20) + 50,($i * 50) + 100,($axisY * 20)+70, $currentColor);
			$gd->fill(($i * 50) + 55,($axisY * 20) + 55, $currentColor);
		}

	} # end $i, $numOfLibs

	$stringArray[$j] =~ s/\t/  /g;

        $gd->string(gdLargeFont,($numOfLibs*50)+120, ($axisY*20)+55,"$stringArray[$j]", $black);

	$axisY++;

} # end $j, $numOfGenes

for (my $i = 0; $i < 128; $i++){
	my $currentColor;
	if ($COLOR eq 'B'){
        	$currentColor = $gd->colorAllocate(0,0,$i*2);
        }
        elsif ($COLOR eq 'R'){
        	$currentColor = $gd->colorAllocate($i*2,0,0);
        }
        elsif ($COLOR eq 'G'){
        	$currentColor = $gd->colorAllocate(0,$i*2,0);
        }
        else{
        	$currentColor = $gd->colorAllocate($i*2,$i*2,$i*2);
       	}
	$gd->line($i+100, ($axisY*20) + 70, $i+100, ($axisY*20) + 90, $currentColor);
}

$gd->string(gdLargeFont, 100, ($axisY*20)+ 100, "0.0000", $black);

my $maxRelativeAbundanceTmp = sprintf "256.0000";

if ($maxRelativeAbundance < 256){
	$maxRelativeAbundanceTmp = sprintf "%4.4f", $maxRelativeAbundance;
}

$gd->string(gdLargeFont, 228, ($axisY*20)+ 100, "$maxRelativeAbundanceTmp", $black);

my $thisProcess = getppid;

system("rm $imageName*.png");

open(MAP, ">$imageName$thisProcess.png") or die "could not open $imageName!\n";
print MAP $gd->png;
close(MAP);

# gerando o documento HTML
print "Content-type: text/html\n\n";
print <<"HTML";
<HTML>
<HEAD>
<TITLE>Digital Northern Picture Generator</TITLE>
<BODY bgcolor=lightblue>
<CENTER>
<IMG SRC='$imageAddress$thisProcess.png'>
</CENTER>
<HR>
</BODY>
</HTML>
HTML

# fim do CGI

exit 0;
