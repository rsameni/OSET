% Sample fetal-maternal ECG generator

clc
clear;
close all;

rand('seed',0);
randn('seed',1);

fs = 400;
N = 4000;
dim1 = 8;

SIR = -30;
SNR = -20;
SNR2 = 5;
beta = 2;

w_bw = 1;       % weight of baseline wander noise in the generated noise (for noisetype = 5)
w_em = 1;       % weight of electrode movement noise in the generated noise (for noisetype = 5)
w_ma = 1;       % weight of muscle artifact noise in the generated noise (for noisetype = 5)


v = zeros(3,N);
v(1,:) = NoiseGenerator(5,1,0,N,fs,[1,0,0],1);
v(2,:) = NoiseGenerator(5,1,0,N,fs,[0,1,0],1);
v(3,:) = NoiseGenerator(5,1,0,N,fs,[0,0,1],1);
noise = randn(dim1,3)*v;
% noise = randn(dim1,3)*v;

% noise2 = cumsum(randn(dim1,N),2);
noise2 = randn(dim1,N);

% % % noise2 = zeros(dim1,N);
% % % beta = 1;     % noise color (for noisetype = 1)
% % % for i = 1:dim1,
% % %     noise2(i,:) = NoiseGenerator(1,1,0,N,fs,beta,rand);
% % % %     noise(i,:) = NoiseGenerator(0,1,0,N,mod(i,3));
% % % %     noise(i,:) =  NoiseGenerator(5,1,0,N,fs,[w_bw,w_em,w_ma],mod(i,2)*1000);
% % % end

%//////////////////////////////////////////////////////////////////////////
% Maternal dipole parameters
F_m = 1.001;                     % maternal heart rate

teta0_m = pi/3.1;

tetai_m.x  = [-1.09  -0.83   -0.19     -.07  0 .06        0.22    1.2 1.42 1.68];
alphai_m.x = [0.03   .08    -0.13    .85 1.11 .75     0.06   0.1  0.17 0.39];
bi_m.x     = [0.0906    0.1057    0.0453    0.0378    0.0332    0.0302    0.0378    0.6040 0.3020    0.1812];

tetai_m.y  = [-1.1  -0.9 -0.76       -0.11   -.01       0.065  0.8      1.58];
alphai_m.y = [0.035 0.015 -0.019     0.32    .51     -0.32    0.04   0.08];
bi_m.y     = [0.07  .07  0.04        0.055    0.037    0.0604  0.450  0.3];

tetai_m.z  = [-1.1  -0.93 -0.7      -.4     -0.15    .095    1.05 1.25 1.55];
alphai_m.z = [-0.03 -0.14 -0.035    .045     -0.4    .46    -.12 -.2 -.35];
bi_m.z     = [.03  .12  .04         .4    .045       .05    .8 .4 .2];


%//////////////////////////////////////////////////////////////////////////
% Fetal dipole parameters
F_f = 2.4;                          % fetal heart rate

teta0_f = -pi/2;

tetai_f.x  = [-0.7    -0.17    0       0.18     1.4];
alphai_f.x = [0.07     -0.11   1.3     0.07   0.03];
bi_f.x     = [.1       .03     .045     0.02    0.3];

tetai_f.y  = [-0.9     -0.08   0       0.05        1.3];
alphai_f.y = [0.04     0.3     .45     -0.35       0.05];
bi_f.y     = [.1       .05      .03    .04         .3];

tetai_f.z  = [-0.8      -.3     -0.1        .06     1.35];
alphai_f.z = [-0.01    .03     -0.4        .46     -0.01];
bi_f.z     = [.1       .4      .03         .03     .3];

%//////////////////////////////////////////////////////////////////////////
[DIP_m, teta_m] = DipoleGenerator2(N,fs,F_m,alphai_m,bi_m,tetai_m,teta0_m);
[DIP_f, teta_f] = DipoleGenerator2(N,fs,F_f,alphai_f,bi_f,tetai_f,teta0_f);

A = [];
while(isempty(A))
    [A,B,ang] = RandomMatrices(10,dim1,0); ext = '_1';
    %     [A,B,ang] = RandomMatrices(60,dim1,1); ext = '_2';
end

xm = A*[DIP_m.x ; DIP_m.y ; DIP_m.z];
xf = B*[DIP_f.x ; DIP_f.y ; DIP_f.z];
ref = [DIP_f.x ; DIP_f.y ; DIP_f.z];

xmpower = sum(sum(xm.^2));
xfpower = sum(sum(xf.^2));
npower = sum(sum(noise.^2));
n2power = sum(sum(noise2.^2));

alpha = sqrt(xfpower/xmpower/10^(SIR/10));
beta = sqrt(xfpower/npower/10^(SNR/10));
gamma = sqrt(xfpower/n2power/10^(SNR2/10));

x = alpha*xm + xf + beta*noise + gamma*noise2;

% % % x = x - LPFilter(x,.7/fs);
% % % x = x - mean(x,2)*ones(1,N);

W = jadeR(x);
A = pinv(W);
s0 = W*x;

s = s0;
% % % ref = ref - mean(ref,2)*ones(1,N);
% % % s = s - mean(s,2)*ones(1,N);
% % % xf = xf - mean(xf,2)*ones(1,N);

wopt = (s*ref')*pinv(ref*ref');
e = mean((s - wopt*ref).^2,2);

[Y, I] = sort(e);

MSE = zeros(dim1,1);
for i = 1:dim1
    y = A(:,I(1:i))*s0(I(1:i),:);       % NOTE: y only resembles xf up-to a certain value of i: from there onwards is gets more similar to x
    %     SINR(i) = 10*log10(sum(sum(y.^2))/sum(sum((xf-y).^2)));
    MSE(i) = sum(sum((xf-y).^2))/sum(sum((xf).^2));
end
MSE
[Y, JJ] = min(MSE);
s = s0;
s(I(JJ:end),:) = 0;
y = pinv(W)*s;

PlotECG(v,3,'m');
PlotECG(x,2,'b');
PlotECG(s0,2,'r');

I = 1:4000;

time = (0:length(I)-1)/fs;
%//////////////////////////////////////////////////////////////////////////
for i = 1:size(x,1)
    h = figure;
    plot(time(I),x(i,I),'k','Linewidth',.5);
    xlabel('time(s)','FontSize',10);
    ylabel('Amplitude(mV)','FontSize',10);
    grid;
    set(gca,'FontSize',10);
    a = axis;
    a(1) = time(1);
    a(2) = time(end);
    axis(a);
    set(h,'PaperUnits','inches');
    set(h,'PaperPosition',[.01 .01 3.5 2.5])
    %     print('-dpng','-r600',['C:\Reza\ECG_Ch',num2str(i),ext,'.png']);
    %     print('-deps','-r600',['C:\Reza\ECG_Ch',num2str(i),ext,'.eps']);
    
    h = figure;
    plot(time(I),s0(i,I),'k','Linewidth',.5);
    xlabel('time(s)','FontSize',10);
    ylabel('Amplitude(mV)','FontSize',10);
    grid;
    set(gca,'FontSize',10);
    a = axis;
    a(1) = time(1);
    a(2) = time(end);
    axis(a);
    set(h,'PaperUnits','inches');
    set(h,'PaperPosition',[.01 .01 3.5 2.5])
    %     print('-dpng','-r600',['C:\Reza\IC_Ch',num2str(i),ext,'.png']);
    %     print('-deps','-r600',['C:\Reza\IC_Ch',num2str(i),ext,'.eps']);
    
end

%//////////////////////////////////////////////////////////////////////////
% % % L = 2;
% % % for i = 1:size(y,1),
% % %     if(mod(i,L)==1)
% % %         figure;
% % %     end
% % %     subplot(L,1,mod(i-1,L)+1);
% % %     plot(xf(i,:),'b');
% % %     hold on;
% % %     plot(y(i,:),'r');
% % %     ylabel(num2str(i));
% % %     grid;
% % % end



