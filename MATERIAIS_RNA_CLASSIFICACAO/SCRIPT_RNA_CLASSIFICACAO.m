% SCRIPT PARA CLASSIFICA��O COM REDES NEURAIS ARTIFICIAIS:
% INCLUI:
% - DIVIS�O ALEAT�RIA DAS AMOSTRAS
% - TRANSFORMA��O DOS DADOS DE ENTRADA (ESCALONAMENTO POR NORMALIZA��O)
% - TREINAMENTO PELO ALGORITMO RETROPROPAGATIVO (BACKPROPAGATION)
% - VALIDA��O CRUZADA PARA EVITAR SUPERAJUSTAMENTO DA REDE
% - ARMAZENAMENTO DOS RESULTADOS E RECURSOS DE PLOTAGEM
% CRIADO POR: Guilherme Garcia de Oliveira
% ATUALIZADO EM: 20/10/2023, 14:00.

clear all
close all
clc 
tic
disp('Carregando dados...')

% -----------------------------------------------------------------------%
% -----------------------------------------------------------------------%
% DEFINI��ES DO USU�RIO: nesta se��o voc� deve fazer altera��es para
% carregar corretamente seus dados amostrais (em formato de tabela), a
% imagem que ser� classificada, bem como indicar a complexidade e outras
% defini��es do modelo de RNA.

% INDIQUE SE DESEJA USAR O EXCEL PARA CARREGAR OS DADOS:
Excel=1; % usar 0 se n�o possui Excel instalado, usar 1 se tiver!

% CARREGAR CONJUNTO AMOSTRAL (INPUTS+OUTPUTS): espera-se que voc� carregue
% todas as suas amostras, em que cada linha da tabela corresponde a um
% pixel ou objeto amostrado sobre a imagem, cada coluna da tabela
% corresponde a uma vari�vel do modelo (primeiro as explicativas, depois as
% dependentes). N�o carregar cabe�alho. N�o pode ter c�lulas vazias no
% intervalo carregado.
if Excel==1
    DADOS=xlsread('AMOSTRAS.xlsx', 'AMOSTRAS', 'C2:N2882');
else
    load AMOSTRAS
end

% CARREGAR IMAGEM A SER CLASSIFICADA:
% carregar a imagem que ser� classificada, com bandas organizadas na mesma
% sequ�ncia das colunas da tabela de amostra.
NomeIMG='L08_OLI_220081_20210525_B234567_REC.tif';
IMG=double(imread(NomeIMG)); [A,R]=geotiffread(NomeIMG);

% DEFINI��ES GERAIS DA REDE NEURAL:
input=6; %n�mero de vari�veis de entrada
nclass=6; %n�mero de classes da vari�vel dependente
nh=7; %n�mero de neur�nios na camada oculta da rede
nit=5; %itera��es: n�mero de inicializa��es da rede
Cic=20000; %ciclos: n�mero m�ximo de ciclos de aprendizagem
ptreina=0.7; %propor��o de amostras para treinamento
pteste=0.15; %propor��o de amostras para teste
f=0; %propor��o de extrapola��o poss�vel na sa�da da RNA
file='RNACLASS.mat'; %nome do arquivo MATLAB para salvar seus resultados
Nomefig='CLASS_BOA.tif'; %nome da imagem classificada

% FIM DAS DEFINI��ES DO USU�RIO
% -----------------------------------------------------------------------%
% -----------------------------------------------------------------------%

disp('Carregamento de dados conclu�da!')

% IN�CIO DO PROCESSAMENTO DE DADOS:
% ETAPA DE DIVIS�O ALEAT�RIA DAS AMOSTRAS:
disp('Dividindo amostras...')
div=rand(size(DADOS,1),1); %cria uma matriz de n�meros aleat�rios entre 0 e 1
treina=[]; valida=[]; verifica=[]; %esvazia matrizes de treinamento, valida��o e teste
for i=1:size(DADOS,1)
    if div(i)<=ptreina
        treina=[treina; DADOS(i,:)]; %#ok<AGROW>
    elseif div(i)>1-pteste
        verifica=[verifica; DADOS(i,:)]; %#ok<AGROW>
    else
        valida=[valida; DADOS(i,:)]; %#ok<AGROW>
    end
end

% FUN��ES PRONTAS - INLINES:
unisig=inline('1./(1+exp(-n))'); %fun��o de ativa��o - sigmoide
dunisig=inline('max(a.*(1-a),0.01)'); %fun��o derivada para retropropaga��o dos erros
limsup=inline('max(v,[],2)+(max(v,[],2)-min(v,[],2)).*f','v','f'); %fun��o que calcula o limite superior dos outputs 
liminf=inline('min(v,[],2)-(max(v,[],2)-min(v,[],2)).*f','v','f'); %fun��o que calcula o limite inferior dos outputs
esclin=inline('(v-b*u)./(a*u)','v','a','b','u'); %fun��o que transforma (reescalona) os dados de entrada
reclin=inline('(a*u).*s+b*u','s','a','b','u'); %fun��o que converte sa�da escalonada em valores reais

% SEPARA��O ENTRE MATRIZES DE INPUTS E OUTPUTS POR DIVIS�O DE AMOSTRAS:
Pt=treina(:,1:input)'; Tt=treina(:,input+1:end)';
Ptv=valida(:,1:input)'; Ttv=valida(:,input+1:end)';
Pv=verifica(:,1:input)'; Tv=verifica(:,input+1:end)';
Ptot=DADOS(:,1:input)'; Ttot=DADOS(:,input+1:end)';

% OUTRAS DEFINI��ES:
EQmin=1000000000000000; Prc=0.001; Mom=0;
As=unisig; Ds=dunisig; Ah=unisig; Dh=dunisig; %chama fun��es de ativa��o e derivada 
Ut=ones(1,size(Pt,2)); Utv=ones(1,size(Ptv,2));
Uv=ones(1,size(Pv,2)); Utot=ones(1,size(Ptot,2)); %cria matrizes de 1 - garante a opera��o de matrizes

% TRANSFORMA��O DOS DADOS (ESCALONAMENTO):
disp('Realizando o escalonamento dos dados...')
nlin=size(IMG,1); ncol=size(IMG,2); npix=nlin*ncol; nb=size(IMG,3);
mIMG=reshape(IMG,npix,nb)'; ae=std(mIMG,[],2); be=mean(mIMG,2);
ls=limsup(Tt,f); li=liminf(Tt,f); au=ls-li; bu=li;
pt=esclin(Pt,ae,be,Ut); ptv=esclin(Ptv,ae,be,Utv);
pv=esclin(Pv,ae,be,Uv); ptot=esclin(Ptot,ae,be,Utot);
tt=esclin(Tt,au,bu,Ut); ttv=esclin(Ttv,au,bu,Utv);
tv=esclin(Tv,au,bu,Uv); ttot=esclin(Ttot,au,bu,Utot);

% TREINAMENTO COM REDES NEURAIS ARTIFICIAIS:
disp('Iniciando o treinamento da rede neural artificial...')
for i=1:nit
    [wh,bh,ws,bs,J,EQ,EV,TX,DE]=Retroprvcfn2(pt,tt,ptv,ttv,Ah,Dh,As,Ds,nh,Cic,Prc,Mom);
    if EQ(:,end)<EQmin, EQmin=EQ(:,end); %s� salva os resultados se RNA melhorou em rela��o � itera��o anterior
        save(file,'wh','bh','ws','bs','J','EQ','EV','TX','DE','ae','be','au','bu'),
    end
    format bank, disp([num2str(i/nit*100),'% CONCLU�DO']),        
end
disp('Rede neural artificial treinada!')

% CLASSIFICA��O DAS AMOSTRAS E C�LCULO DA MATRIZ DE CONFUS�O:
disp('Gerando matriz de confus�o...')
load(file),      
Tctot=reclin(As(ws*Ah(wh*ptot+bh*Utot)+bs*Utot),au,bu,Utot); %roda RNA treinada para a totalidade das amostras
Tc=reclin(As(ws*Ah(wh*pv+bh*Uv)+bs*Uv),au,bu,Uv); %roda RNA treinada para amostras de teste
Mtot=max(Ttot,[],1); Mctot=max(Tctot,[],1);
Mtst=max(Tv,[],1); Mctst=max(Tc,[],1);
ClasTot=zeros(size(Ttot,2),2); ClasTst=zeros(size(Tv,2),2);
MatrixTot=zeros(nclass,nclass); MatrixTst=MatrixTot;
for i=1:size(Ttot,2)
    %classifica todas as amostras em classes de 1 at� nclass
    ClasTot(i,1)=find(Ttot(:,i)==Mtot(i)); ClasTot(i,2)=find(Tctot(:,i)==Mctot(i));
    %gera a matriz de confus�o considerando a totalidade das amostras
    MatrixTot(ClasTot(i,1),ClasTot(i,2))=MatrixTot(ClasTot(i,1),ClasTot(i,2))+1;
end
for i=1:size(Tv,2)
    %classifica as amostras de teste em classes de 1 at� nclass
    ClasTst(i,1)=find(Tv(:,i)==Mtst(i)); ClasTst(i,2)=find(Tc(:,i)==Mctst(i));
    %gera a matriz de confus�o considerando apenas amostras de teste
    MatrixTst(ClasTst(i,1),ClasTst(i,2))=MatrixTst(ClasTst(i,1),ClasTst(i,2))+1;
end

% ACUR�CIA DA CLASSIFICA��O E �NDICE KAPPA:
disp('Calculando acur�cia e �ndice Kappa...')
AcertosTot=0; AcertosTst=0; k2Tot=0; k2Tst=0;
AmTot=size(ClasTot,1); AmTst=size(ClasTst,1);
SomaClasTot=sum(MatrixTot); SomaRefTot=sum(MatrixTot,2);
SomaClasTst=sum(MatrixTst); SomaRefTst=sum(MatrixTst,2);
for i=1:nclass
    % computa os acertos de classifica��o:
    AcertosTot=AcertosTot+MatrixTot(i,i);
    AcertosTst=AcertosTst+MatrixTst(i,i);
    % calcula o par�metro k2 do �ndice kappa:
    k2Tot=k2Tot+(SomaClasTot(i)/AmTot)*(SomaRefTot(i)/AmTot);
    k2Tst=k2Tst+(SomaClasTst(i)/AmTst)*(SomaRefTst(i)/AmTst);
end
ACCTot=AcertosTot/AmTot; ACCTst=AcertosTst/AmTst; %computa a acur�cia
KappaTot=(ACCTot-k2Tot)/(1-k2Tot); KappaTst=(ACCTst-k2Tst)/(1-k2Tst); %computa o kappa

% CLASSIFICA��O DA IMAGEM DE SAT�LITE:
disp('Classificando imagem de sat�lite e salvando TIF...')
Uimg=ones(1,size(mIMG,2)); %cria matriz de 1 para usar a RNA em toda a imagem
Eimg=esclin(mIMG,ae,be,Uimg); %escalona os valores de todos os pixels da imagem a ser classificada
Cimg=reclin(As(ws*Ah(wh*Eimg+bh*Uimg)+bs*Uimg),au,bu,Uimg); %calcula as sa�das da RNA para todos os pixels da imagem
Mimg=max(Cimg,[],1); Clasimg=zeros(1,size(Cimg,2));
for i=1:size(Cimg,2)
    Clasimg(i)=find(Cimg(:,i)==Mimg(i)); %classifica a imagem em classes de 1 a nclass    
end
CLASS=reshape(Clasimg,nlin,ncol,1); %gera a imagem classificada em forma de matriz
%geotiffwrite(Nomefig,CLASS,R,'CoordRefSysCode',32722); % salva imagem classifica em TIF
CLASSint = int8(CLASS);

% criando po filtro de maiores ocororrencias
for i=2:nlin-2
    for j=2:ncol-2
        movel_window = CLASSint(i-1:i+1,j-1:j+1);
        for k=1:nclass
            counter(k) = size(find(movel_window==k),1);
        end
    end
end

geotiffwrite(Nomefig,CLASSint,R,'CoordRefSysCode',32722); % salva imagem classifica em TIF


% MOSTRA NA TELA OS PRINCIPAIS RESULTADOS, SALVA E FINALIZA PROGRAMA:
disp('RESUMO: PRINCIPAIS RESULTADOS DO PROCESSO DE CLASSIFICA��O:')
disp(['N�mero de inputs: ',num2str(input)])
disp(['N�mero de neur�nios na camada oculta: ',num2str(nh)])
disp(['N�mero de inicializa��es da rede (itera��es): ',num2str(nit)])
disp(['N�mero m�ximo de ciclos de aprendizagem: ',num2str(Cic)])
disp(['N�mero de ciclos para converg�ncia: ',num2str(J)])
disp('Matriz de confus�o (todas as amostras):')
disp(MatrixTot)
disp('Matriz de confus�o (amostras de teste):')
disp(MatrixTst)
disp(['Acur�cia Global (todas as amostras): ',num2str(ACCTot)])
disp(['Acur�cia Global (amostras de teste): ',num2str(ACCTst)])
disp(['�ndice Kappa (todas as amostras): ',num2str(KappaTot)])
disp(['�ndice Kappa (amostras de teste): ',num2str(KappaTst)])
save(file) %salva arquivo .MAT com todos os arquivos gerados no processo de modelagem e classifica��o
toc