function spectra = spinwave(obj, hkl, varargin)
% calculates dynamical spin-spin correlation function using linear spin wave theory
%
% spectra = SPINWAVE(obj, hkl, 'option1', value1 ...)
%
% Spin wave dispersion and spin-spin correlation function is calculated at
% the reciprocal space points k. The function can deal with arbitrary
% magnetic structure and magnetic interactions as well as single ion
% anisotropy and magnetic field. Biquadratic exchange interactions are also
% implemented, however only for k=0 magnetic structures.
%
% If the magnetic ordering wavevector is non-integer, the dispersion is
% calculated using a coordinate system rotating from cell to cell. In this
% case the spin Hamiltonian has to fulfill this extra rotational symmetry.
%
% Input:
%
% obj           Input structure, spinw class object.
% hkl           Defines the Q points where the spectra is calculated, in
%               reciprocal lattice units, size is [3 nHkl]. Q can be also
%               defined by several linear scan in reciprocal space. In this
%               case hkl is cell type, where each element of the cell
%               defines a point in Q space. Linear scans are assumed
%               between consecutive points. Also the number of Q points can
%               be specified as a last element, it is 100 by defaults. For
%               example: hkl = {[0 0 0] [1 0 0]  50}, defines a scan along
%               (h,0,0) from 0 to 1 and 50 Q points are calculated along
%               the scan.
%
%               For symbolic calculation at a general reciprocal space
%               point use sym class input. For example to calculate the
%               spectrum along (h,0,0): hkl = [sym('h') 0 0]. To
%               do calculation at a specific point do for example
%               sym([0 1 0]), to calculate the spectrum at (0,1,0).
%
% Options:
%
% formfact      If true, the magnetic form factor is included in the
%               spin-spin correlation function calculation. The form factor
%               coefficients are stored in obj.unit_cell.ff(1,:,atomIndex).
%               Default value is false.
% formfactfun   Function that calculates the magnetic form factor for given
%               Q value. Default value is @sw_mff(), that uses a tabulated
%               coefficients for the form factor calculation. For
%               anisotropic form factors a user defined function can be
%               written that has the following header:
%                   F = @formfactfun(atomLabel,Q)
%               where the parameters are:
%                   F   row vector containing the form factor for every
%                       input Q value
%                   atomLabel string, label of the selected magnetic atom
%                   Q   matrix with dimensions of [3 nQ], where each column
%                       contains a Q vector in Angstrom^-1 units.
% gtensor       If true, the g-tensor will be included in the spin-spin
%               correlation function. Including anisotropic g-tensor or
%               different g-tensor for different ions is only possible
%               here. Including a simple isotropic g-tensor is possible
%               afterwards using the sw_instrument() function.
% fitmode       Speedup (for fitting mode only), default is false.
% notwin        If true, the spectra of the twins won't be calculated.
%               Default is false.
% sortMode      The spin wave modes will be sorted if true. Default is
%               true.
% optmem        Parameter to optimise memory usage. The list of hkl values
%               will be cut into optmem number of pieces and will be
%               calculated piece by piece to decrease memory usage. Default
%               of optmem is zero, when the number of slices are determined
%               automatically from the available free memory.
% tol           Tolerance of the incommensurability of the magnetic
%               ordering wavevector. Deviations from integer values of the
%               ordering wavevector smaller than the tolerance are
%               considered to be commensurate. Default value is 1e-4.
% omega_tol     Tolerance on the energy difference of degenerate modes when
%               diagonalising the quadratic form, default is 1e-5.
% hermit        Method for matrix diagonalization:
%                   true      J.H.P. Colpa, Physica 93A (1978) 327,
%                   false     R.M. White, PR 139 (1965) A450.
%               Colpa: the grand dynamical matrix is converted into another
%                      Hermitian matrix, that will give the real
%                      eigenvalues.
%               White: the non-Hermitian g*H matrix will be diagonalised,
%                      that is not the elegant method.
%               Advise:
%               Always use Colpa's method, except when small imaginary
%               eigenvalues are expected. In this case only White's method
%               work. The solution in this case is wrong, however by
%               examining the eigenvalues it can give a hint where the
%               problem is.
%               Default is true.
% saveH         If true, the quadratic form of the Hamiltonian is saved. Be
%               carefull, it can take up lots of memory. Default is false.
% saveV         If true, the matrices that transform the normal magnon
%               modes into the magnon modes localized on the spins are
%               saved. Be carefull, it can take up lots of memory.
%               Default is false.
% saveSabp      If true, the dynamical structure factorin the rotating
%               frame is saved S'(k,omega). Default is false.
% title         Gives a title string to the simulation that is saved in the
%               output.
% useMex        If true, the code will use compiled mex files (if they
%               exist) to speed up the calculation, for details see
%               sw_mex() function. Default is false.
%
% Output:
%
% 'spectra' is a structure, with the following fields:
% omega         Calculated spin wave dispersion, dimensins are
%               [nMode nHkl], where nMagExt is the number of magnetic
%               atoms in the extended unit cell.
% Sab           Dynamical structure factor, dimensins are
%               [3 3 nMode nHkl]. Each (:,:,i,j) submatrix contains the
%               9 correlation functions: Sxx, Sxy, Sxz, etc. If given,
%               magnetic form factor is included. Intensity is in hBar
%               units, normalized to the crystallographic unit cell.
% H             Quadratic form of the Hamiltonian.
%               Only saved if saveH is true.
% V             Transformation matrix from the normal magnon modes to the
%               magnons localized on spins:
%                   x_i = sum_j V_ij * x_j'
%               Only saved if saveV is true.
% Sabp          Dynamical structure factor in the rotating frame,
%               dimensions are [3 3 nMode nHkl], but the number of modes
%               are equal to twice the number of magnetic atoms.
% formfact      Cell containing the labels of the magnetic ions if form
%               factor in included in the spin-spin correlation function.
% cmplxBase     The local coordinate system on each magnetic moment is
%               defined by the complex magnetic moments:
%                   e1 = imag(M/norm(M))
%                   e3 = real(M/norm(M))
%                   e2 = cross(e3,e1)
%
% nMode is the number of magnetic mode. For commensurate structures it is
% double the number of magnetic atoms in the magnetic cell/supercell. For
% incommensurate structures this number is tripled due to the appearance of
% the (Q+/-km) Fourier components in the correlation functions. For every k
% points in the following order: (k-km,k,k+km).
%
% If several twins exist in the sample, omega and Sab are packaged into a
% cell, that contains nTwin number of matrices.
%
% hkl           Contains the input Q values, dimensins are [3 nHkl].
% hklA          Same Q values, but in reciproc Angstrom units in the
%               lab coordinate system, dimensins are [3 nHkl].
% incomm        Whether the spectra calculated is incommensurate or not.
% obj           The copy of the input obj.
%
% Example:
%
% tri = sw_model('triAF',1);
% sw_plotspec(tri.spinwave({[0 0 0] [1 1 0]}))
%
% The above example will calculate and plot the spin wave dispersion of the
% triangular lattice antiferromagnet (S=1, J=1) along the [H H 0] direction
% in reciprocal space.
%
% See also SPINW, SPINW.SPINWAVESYM, SW_NEUTRON, SPINW.POWSPEC, SPINW.OPTMAGSTR, SPINW.FILEID, SW_INSTRUMENT.
%

% for linear scans create the Q line(s)
if nargin > 1
    hkl = sw_qscan(hkl);
else
    hkl = [];
end

% calculate symbolic spectrum if obj is in symbolic mode
if obj.symbolic
    if numel(hkl) == 3
        hkl = sym(hkl);
    end
    
    if ~isa(hkl,'sym')
        inpForm.fname  = {'fitmode'};
        inpForm.defval = {false    };
        inpForm.size   = {[1 1]    };
        param0 = sw_readparam(inpForm, varargin{:});
        
        if ~param0.fitmode
            warning('spinw:spinwave:MissingInput','No hkl value was given, spin wave spectrum for general Q (h,k,l) will be calculated!');
        end
        spectra = obj.spinwavesym(varargin{:});
    else
        spectra = obj.spinwavesym(varargin{:},'hkl',hkl);
    end
    return
end

% help when executed without argument
if nargin==1
    help sw.spinwave
    spectra = [];
    return
end

title0 = 'Numerical LSWT spectrum';

inpForm.fname  = {'fitmode' 'notwin' 'sortMode' 'optmem' 'tol' 'hermit'};
inpForm.defval = {false     false    true       0        1e-4  true    };
inpForm.size   = {[1 1]     [1 1]    [1 1]      [1 1]    [1 1] [1 1]   };

inpForm.fname  = [inpForm.fname  {'omega_tol' 'saveSabp' 'saveV' 'saveH'}];
inpForm.defval = [inpForm.defval {1e-5        true       false   false  }];
inpForm.size   = [inpForm.size   {[1 1]       [1 1]      [1 1]   [1 1]  }];

inpForm.fname  = [inpForm.fname  {'formfact' 'formfactfun' 'title' 'gtensor'}];
inpForm.defval = [inpForm.defval {false       @sw_mff      title0  false    }];
inpForm.size   = [inpForm.size   {[1 -1]      [1 1]        [1 -2]  [1 1]    }];

inpForm.fname  = [inpForm.fname  {'useMex' 'cmplxBase' 'tid' 'fid' }];
inpForm.defval = [inpForm.defval {false    false       -1    nan   }];
inpForm.size   = [inpForm.size   {[1 1]    [1 1]       [1 1] [1 1] }];

param = sw_readparam(inpForm, varargin{:});

if isnan(param.fid)
    % Print output into the following file
    fid = obj.fid;
else
    fid = param.fid;
end

if ~param.fitmode
    % save the time of the beginning of the calculation
    spectra.datestart = datestr(now);
end

if param.fitmode
    param.sortMode = false;
    param.tid = 0;
end

if param.tid == -1
    param.tid = swpref.getpref('tid',[]);
end

if param.useMex == -1
    % don't check files (takes too much time)
    param.useMex = true;
    % elseif ~(param.useMex && exist('chol_omp','file')==3 && ...
    %         exist('eig_omp','file')==3 && exist('sw_mtimesx','file')==3)
elseif ~(param.useMex && exist('chol_omp','file')==3 && ...
        exist('eig_omp','file')==3)
    % check if mex files exist
    param.useMex = false;
end

% generate magnetic structure in the rotating noation
magStr = obj.magstr;

% size of the extended magnetic unit cell
nExt    = magStr.N_ext;
% magnetic ordering wavevector in the extended magnetic unit cell
km = magStr.k.*nExt;

% whether the structure is incommensurate
incomm = any(abs(km-round(km)) > param.tol);

% Calculates momentum transfer in A^-1 units.
hklA = 2*pi*(hkl'/obj.basisvector)';

% Check for 2*km
tol = param.tol*2;
helical =  sum(abs(mod(abs(2*km)+tol,1)-tol).^2) > tol;

% number of Q points
nHkl0 = size(hkl,2);

% define Q scans for the twins
nTwin = size(obj.twin.vol,2);
if param.notwin
    nTwin = 1;
end

% if the single twin has no rotation set param.notwin true
rotc1 = obj.twin.rotc(:,:,1)-eye(3);
if (nTwin == 1) && norm(rotc1(:))==0
    param.notwin = true;
end

if ~param.notwin
    % In the abc coordinate system of the selected twin the scan is
    % rotated opposite direction to rotC.
    hkl  = obj.twinq(hkl);
    nHkl = nHkl0*nTwin;
else
    nHkl = nHkl0;
    hkl  = {hkl};
end

if incomm
    % TODO
    if ~helical
        warning('sw:spinwave:Twokm',['The two times the magnetic ordering '...
            'wavevector 2*km = G, reciproc lattice vector, use magnetic supercell to calculate spectrum!']);
    end
    
    hkl0 = cell(1,nTwin);
    hklExt = cell(1,nTwin);
    
    for tt = 1:nTwin
        % without the k_m: (k, k, k)
        hkl0{tt} = repmat(hkl{tt},[1 3]);
        
        % for wavevectors in the extended unit cell km won't be multiplied by
        % nExt (we devide here to cancel the multiplication later)
        kme = km./nExt;
        hklExt{tt}  = [bsxfun(@minus,hkl{tt},kme') hkl{tt} bsxfun(@plus,hkl{tt},kme')];
        
        % calculate dispersion for (k-km, k, k+km)
        hkl{tt}  = [bsxfun(@minus,hkl{tt},km') hkl{tt} bsxfun(@plus,hkl{tt},km')];
    end
    nHkl  = nHkl*3;
    nHkl0 = nHkl0*3;
else
    hkl0   = hkl;
    hklExt = hkl;
end

hkl    = cell2mat(hkl);
hkl0   = cell2mat(hkl0);
hklExt = cell2mat(hklExt);

% determines a twin index for every q point
twinIdx = repmat(1:nTwin,[nHkl 1]);
twinIdx = twinIdx(:);

% Create the interaction matrix and atomic positions in the extended
% magnetic unit cell.
[SS, SI, RR] = obj.intmatrix('fitmode',true,'conjugate',true);

% add the dipolar interactions to SS.all
SS.all = [SS.all SS.dip];

% is there any biquadratic exchange
bq = SS.all(15,:)==1;

% Biquadratic exchange only supported for commensurate structures
if incomm && any(bq)
    error('sw:spinwave:Biquadratic','Biquadratic exchange can be only calculated for k=0 structures!');
end

if any(bq)
    % Separate the biquadratic couplings
    % Just use the SS.bq matrix produced by intmatrix(), it won't contain
    % the transpose matrices (not necessary for biquadratic exchange)
    % TODO check whether to keep the transposed matrices to be sure
    SS.bq = SS.all(1:6,bq);
    % Keep only the quadratic exchange couplings
    SS.all = SS.all(1:14,SS.all(15,:)==0);
end

% Converts wavevctor list into the extended unit cell
hklExt  = bsxfun(@times,hklExt,nExt')*2*pi;
% q values without the +/-k_m value
hklExt0 = bsxfun(@times,hkl0,nExt')*2*pi;

% Calculates parameters eta and zed.
if isempty(magStr.S)
    error('sw:spinwave:NoMagneticStr','No magnetic structure defined in obj!');
end

M0 = magStr.S;
S0 = sqrt(sum(M0.^2,1));
% normal to rotation of the magnetic moments
n  = magStr.n;
nMagExt = size(M0,2);

if incomm
    fprintf0(fid,['Calculating INCOMMENSURATE spin wave spectra '...
        '(nMagExt = %d, nHkl = %d, nTwin = %d)...\n'],nMagExt, nHkl0, nTwin);
else
    fprintf0(fid,['Calculating COMMENSURATE spin wave spectra '...
        '(nMagExt = %d, nHkl = %d, nTwin = %d)...\n'],nMagExt, nHkl0, nTwin);
end

% Local (e1,e2,e3) coordinate system fixed to the moments,
% e3||Si,ata
% e2 = Si x [1,0,0], if Si || [1,0,0] --> e2 = [0,0,1]
% e1 = e2 x e3
% Local (e1,e2,e3) coordinate system fixed to the moments.
% TODO add the possibility that the coordinate system is fixed by the
% comples magnetisation vectors: e1 = imag(M), e3 = real(M), e2 =
% cross(e3,e1)
if ~param.cmplxBase
    if obj.symbolic
        e3 = simplify(M0./[S0; S0; S0]);
        % e2 = Si x [1,0,0], if Si || [1,0,0] --> e2 = [0,0,1]
        e2  = [zeros(1,nMagExt); e3(3,:); -e3(2,:)];
        % select zero vector and make them parallel to [0,0,1]
        selidx = abs(e2)>0;
        if isa(selidx,'sym')
            e2(3,~any(~sw_always(abs(e2)==0))) = 1;
        else
            e2(3,~any(abs(e2)>0)) = 1;
        end
        E0 = sqrt(sum(e2.^2,1));
        e2  = simplify(e2./[E0; E0; E0]);
        % e1 = e2 x e3
        e1  = simplify(cross(e2,e3));
    else
        % e3 || Si
        e3 = bsxfun(@rdivide,M0,S0);
        % e2 = Si x [1,0,0], if Si || [1,0,0] --> e2 = [0,0,1]
        e2  = [zeros(1,nMagExt); e3(3,:); -e3(2,:)];
        e2(3,~any(abs(e2)>1e-10)) = 1;
        e2  = bsxfun(@rdivide,e2,sqrt(sum(e2.^2,1)));
        % e1 = e2 x e3
        e1  = cross(e2,e3);
    end
else
    F0  = obj.mag_str.F;
    RF0 = sqrt(sum(real(F0).^2,1));
    IF0 = sqrt(sum(imag(F0).^2,1));
    % e3 = real(M)
    e3  = real(F0)./repmat(RF0,[3 1]);
    % e1 = imag(M) perpendicular to e3
    e1  = imag(F0)./repmat(IF0,[3 1]);
    e1  = e1-bsxfun(@times,sum(e1.*e3,1),e3);
    e1  = e1./repmat(sqrt(sum(e1.^2,1)),[3 1]);
    % e2 = cross(e3,e1)
    e2  = cross(e3,e1);
    
    if obj.symbolic
        e1 = simplify(e1);
        e2 = simplify(e2);
        e3 = simplify(e3);
    end
    
end
% assign complex vectors that define the rotating coordinate system on
% every magnetic atom
zed = e1 + 1i*e2;
eta = e3;

dR    = [SS.all(1:3,:) zeros(3,nMagExt)];
atom1 = [SS.all(4,:)   1:nMagExt];
atom2 = [SS.all(5,:)   1:nMagExt];
% magnetic couplings, 3x3xnJ
JJ = cat(3,reshape(SS.all(6:14,:),3,3,[]),SI.aniso);

if incomm
    % transform JJ due to the incommensurate wavevector
    [~, K] = sw_rot(n,km*dR*2*pi);
    % multiply JJ with K matrices for every interaction
    % and symmetrising JJ for the rotating basis
    JJ = (mmat(JJ,K)+mmat(K,JJ))/2;
end

nCoupling = size(JJ,3);

zedL = repmat(permute(zed(:,atom1),[1 3 2]),[1 3 1]);
zedR = repmat(permute(zed(:,atom2),[3 1 2]),[3 1 1]);

etaL = repmat(permute(eta(:,atom1),[1 3 2]),[1 3 1]);
etaR = repmat(permute(eta(:,atom2),[3 1 2]),[3 1 1]);

SiSj = sqrt(S0(atom1).*S0(atom2));

% Creates temporary values for calculating matrix elements.
AD  =  shiftdim(sum(sum(etaL.*JJ.*etaR,2),1),1);
A20 = -S0(atom2).*AD;
D20 = -S0(atom1).*AD;
BC0 =  SiSj.*shiftdim(sum(sum(zedL.*JJ.*     zedR ,2),1),1);
AD0 =  SiSj.*shiftdim(sum(sum(zedL.*JJ.*conj(zedR),2),1),1);

% Magnetic field is different for every twin
%MF  =  repmat(obj.unit.muB*SI.field*eta,[1 2]);
MF = zeros(1,2*nMagExt,nTwin);
for ii = 1:nTwin
    % rotate the magnetic field to the relative direction of every twin
    % backward rotation with the rotc matrix of the twin
    twinB = SI.field*obj.twin.rotc(:,:,ii)*obj.unit.muB;
    MF(:,:,ii) = repmat(twinB*permute(mmat(SI.g,permute(eta,[1 3 2])),[1 3 2]),[1 2]);
end

% Creates the serial indices for every matrix element in ham matrix.
idxA1 = [atom1'         atom2'         ];
idxA2 = [atom1'         atom1'         ];
idxB  = [atom1'         atom2'+nMagExt ];
% transpose of idxB
%idxC  = [atom2'+nMagExt atom1'         ]; % SP1
idxD1 = idxA1+nMagExt;
idxD2 = [atom2'+nMagExt atom2'+nMagExt ];
idxMF = [(1:2*nMagExt)' (1:2*nMagExt)' ];

% Calculate matrix elements for biquadratic exchange
if any(bq)
    bqdR    = SS.bq(1:3,:);
    bqAtom1 = SS.bq(4,:);
    bqAtom2 = SS.bq(5,:);
    bqJJ    = SS.bq(6,:);
    nbqCoupling = numel(bqJJ);
    
    % matrix elements: M,N,P,Q
    bqM = sum(eta(:,bqAtom1).*eta(:,bqAtom2),1);
    bqN = sum(eta(:,bqAtom1).*zed(:,bqAtom2),1);
    bqO = sum(zed(:,bqAtom1).*zed(:,bqAtom2),1);
    bqP = sum(conj(zed(:,bqAtom1)).*zed(:,bqAtom2),1);
    bqQ = sum(zed(:,bqAtom1).*eta(:,bqAtom2),1);
    
    Si = S0(bqAtom1);
    Sj = S0(bqAtom2);
    % C_ij matrix elements
    bqA0 = (Si.*Sj).^(3/2).*(bqM.*conj(bqP) + bqQ.*conj(bqN)).*bqJJ;
    bqB0 = (Si.*Sj).^(3/2).*(bqM.*bqO + bqQ.*bqN).*bqJJ;
    bqC  = Si.*Sj.^2.*(conj(bqQ).*bqQ - 2*bqM.^2).*bqJJ;
    bqD  = Si.*Sj.^2.*(bqQ).^2.*bqJJ;
    
    % Creates the serial indices for every matrix element in ham matrix.
    % Aij(k) matrix elements (b^+ b)
    idxbqA  = [bqAtom1' bqAtom2'];
    % b b^+ elements
    idxbqA2 = [bqAtom1' bqAtom2']+nMagExt;
    
    % Bij(k) matrix elements (b^+ b^+)
    idxbqB  = [bqAtom1' bqAtom2'+nMagExt];
    % transpose of B (b b)
    %idxbqB2 = [bqAtom2'+nMagExt bqAtom1']; % SP2
    
    idxbqC  = [bqAtom1' bqAtom1'];
    idxbqC2 = [bqAtom1' bqAtom1']+nMagExt;
    
    idxbqD  = [bqAtom1' bqAtom1'+nMagExt];
    %idxbqD2 = [bqAtom1'+nMagExt bqAtom1]; % SP2
    
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MEMORY MANAGEMENT LOOP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if param.optmem == 0
    freeMem = sw_freemem;
    if freeMem > 0
        nSlice = ceil(nMagExt^2*nHkl*6912/freeMem*2);
    else
        nSlice = 1;
        if ~param.fitmode
            warning('sw:spinwave:FreeMemSize','The size of the free memory is unkown, no memory optimisation!');
        end
    end
else
    nSlice = param.optmem;
end

if nHkl < nSlice
    fprintf0(fid,['Memory allocation is not optimal, nMagExt is'...
        ' too large compared to the free memory!\n']);
    nSlice = nHkl;
elseif nSlice > 1
    fprintf0(fid,['To optimise memory allocation, Q is cut'...
        ' into %d pieces!\n'],nSlice);
end

% message for magnetic form factor calculation
ffstrOut = {'No' 'The'};
fprintf0(fid,[ffstrOut{param.formfact+1} ' magnetic form factor is'...
    ' included in the calculated structure factor.\n']);

% message for g-tensor calculation
if param.gtensor
    gstrOut = 'The';
else
    gstrOut = 'No';
end
fprintf0(fid,[gstrOut ' g-tensor is included in the spin-spin correlation function.\n']);

if param.gtensor
    
    gtensor = SI.g;
    
    if incomm
        % keep the rotation invariant part of g-tensor
        nx  = [0 -n(3) n(2);n(3) 0 -n(1);-n(2) n(1) 0];
        nxn = n'*n;
        m1  = eye(3);
        gtensor = 1/2*gtensor - 1/2*mmat(mmat(nx,gtensor),nx) + 1/2*mmat(mmat(nxn-m1,gtensor),nxn) + 1/2*mmat(mmat(nxn,gtensor),2*nxn-m1);
    end
end

hklIdx = [floor(((1:nSlice)-1)/nSlice*nHkl)+1 nHkl+1];

% Empty omega dispersion of all spin wave modes, size: 2*nMagExt x nHkl.
omega = zeros(2*nMagExt,0);

% empty Sab
Sab = zeros(3,3,2*nMagExt,0);

% Empty matrices to save different intermediate results for further
% analysis: Hamiltonian, eigenvectors, dynamical structure factor in the
% rotating frame
if param.saveV
    Vsave = zeros(2*nMagExt,2*nMagExt,nHkl);
end
if param.saveH
    Hsave = zeros(2*nMagExt,2*nMagExt,nHkl);
end

sw_status(0,1,param.tid,'Spin wave spectrum calculation');

warn1 = false;

% calculate all magnetic form factors
if param.formfact
    spectra.formfact = true;
    % Angstrom^-1 units for Q
    hklA0 = 2*pi*(hkl0'/obj.basisvector)';
    % store form factor per Q point for each atom in the magnetic supercell
    % TODO check prod(nExt)? instead of nExt
    %FF = repmat(param.formfactfun(permute(obj.unit_cell.ff(1,:,obj.matom.idx),[3 2 1]),hklA0),[1 nExt]);
    FF = repmat(param.formfactfun(permute(obj.unit_cell.ff(1,:,obj.matom.idx),[3 2 1]),hklA0),[prod(nExt) 1]);
else
    spectra.formfact = false;
end

for jj = 1:nSlice
    % q indices selected for every chunk
    hklIdxMEM  = hklIdx(jj):(hklIdx(jj+1)-1);
    % q values contatining the k_m vector
    hklExtMEM  = hklExt(:,hklIdxMEM);
    % q values without the +/-k_m vector
    hklExt0MEM = hklExt0(:,hklIdxMEM);
    % twin indices for every q point
    twinIdxMEM = twinIdx(hklIdxMEM);
    nHklMEM = size(hklExtMEM,2);
    
    % Creates the matrix of exponential factors nCoupling x nHkl size.
    % Extends dR into 3 x 3 x nCoupling x nHkl
    %     ExpF = exp(1i*permute(sum(repmat(dR,[1 1 nHklMEM]).*repmat(...
    %         permute(hklExtMEM,[1 3 2]),[1 nCoupling 1]),1),[2 3 1]))';
    ExpF = exp(1i*permute(sum(bsxfun(@times,dR,permute(hklExtMEM,[1 3 2])),1),[2 3 1]))';
    
    % Creates the matrix elements containing zed.
    A1 = bsxfun(@times,     AD0 ,ExpF);
    B  = bsxfun(@times,     BC0 ,ExpF);
    D1 = bsxfun(@times,conj(AD0),ExpF);
    
    
    
    % Store all indices
    % SP1: speedup for creating the matrix elements
    %idxAll = [idxA1; idxB; idxC; idxD1]; % SP1
    idxAll   = [idxA1; idxB; idxD1];
    % Store all matrix elements
    %ABCD   = [A1     B     conj(B)  D1]; % SP1
    ABCD   = [A1     2*B      D1];
    
    % Stores the matrix elements in ham.
    %idx3   = repmat(1:nHklMEM,[4*nCoupling 1]); % SP1
    idx3   = repmat(1:nHklMEM,[3*nCoupling 1]);
    idxAll = [repmat(idxAll,[nHklMEM 1]) idx3(:)];
    idxAll = idxAll(:,[2 1 3]);
    
    ABCD   = ABCD';
    
    
    % quadratic form of the boson Hamiltonian stored as a square matrix
    ham = accumarray(idxAll,ABCD(:),[2*nMagExt 2*nMagExt nHklMEM]);
    
    ham = ham + repmat(accumarray([idxA2; idxD2],2*[A20 D20],[1 1]*2*nMagExt),[1 1 nHklMEM]);
    
    if any(bq)
        % bqExpF = exp(1i*permute(sum(repmat(bqdR,[1 1 nHklMEM]).*repmat(...
        %     permute(hklExtMEM,[1 3 2]),[1 nbqCoupling 1]),1),[2 3 1]))';
        bqExpF = exp(1i*permute(sum(bsxfun(@times,bqdR,permute(hklExtMEM,[1 3 2])),1),[2 3 1]))';
        
        bqA  = bsxfun(@times,     bqA0, bqExpF);
        bqA2 = bsxfun(@times,conj(bqA0),bqExpF);
        bqB  = bsxfun(@times,     bqB0, bqExpF);
        idxbqAll = [idxbqA; idxbqA2; idxbqB];
        %bqABCD = [bqA bqA2 2*bqB];
        bqABCD = [bqA bqA2 2*bqB];
        bqidx3   = repmat(1:nHklMEM,[3*nbqCoupling 1]);
        idxbqAll = [repmat(idxbqAll,[nHklMEM 1]) bqidx3(:)];
        idxbqAll = idxbqAll(:,[2 1 3]);
        bqABCD = bqABCD';
        % add biquadratic exchange
        ham = ham + accumarray(idxbqAll,bqABCD(:),[2*nMagExt 2*nMagExt nHklMEM]);
        % add diagonal terms
        ham = ham + repmat(accumarray([idxbqC; idxbqC2; idxbqD],[bqC bqC 2*bqD],[1 1]*2*nMagExt),[1 1 nHklMEM]);
        
    end
    if any(SI.field)
        % different field for different twin
        for ii = min(twinIdxMEM):max(twinIdxMEM)
            nTwinQ = sum(twinIdxMEM==ii);
            ham(:,:,twinIdxMEM==ii) = ham(:,:,twinIdxMEM==ii) + ...
                repmat(accumarray(idxMF,MF(:,:,ii),[1 1]*2*nMagExt),[1 1 nTwinQ]);
        end
        
        %ham = ham + repmat(accumarray(idxMF,MF,[1 1]*2*nMagExt),[1 1 nHklMEM]);
    end
    
    ham = (ham + conj(permute(ham,[2 1 3])))/2;
    
    % diagonal of the boson commutator matrix
    gCommd = [ones(nMagExt,1); -ones(nMagExt,1)];
    % boson commutator matrix
    gComm  = diag(gCommd);
    %gd = diag(g);
    
    if param.hermit
        % All the matrix calculations are according to Colpa's paper
        % J.H.P. Colpa, Physica 93A (1978) 327-353
        
        % basis functions of the magnon modes
        V = zeros(2*nMagExt,2*nMagExt,nHklMEM);
        
        if param.useMex && nHklMEM>1
            % use mex files to speed up the calculation
            % mex file will return an error if the matrix is not positive definite.
            [K2, invK] = chol_omp(ham,'Colpa','tol',param.omega_tol);
            [V, omega(:,hklIdxMEM)] = eig_omp(K2,'sort','descend');
            % the inverse of the para-unitary transformation V
            for ii=1:nMagExt; 
                V(:,ii,:) = bsxfun(@times, squeeze(V(:,ii,:)), sqrt(omega(ii,hklIdxMEM))); 
                V(:,ii+nMagExt,:) = bsxfun(@times, squeeze(V(:,ii+nMagExt,:)), sqrt(-omega(ii+nMagExt,hklIdxMEM))); 
            end
            V = sw_mtimesx(invK,V);
        else
            for ii = 1:nHklMEM
                [K, posDef]  = chol(ham(:,:,ii));
                if posDef > 0
                    try
                        K = chol(ham(:,:,ii)+eye(2*nMagExt)*param.omega_tol);
                        warn1 = true;
                    catch PD
                        error('sw:spinwave:NonPosDefHamiltonian',...
                            ['Hamiltonian matrix is not positive definite, probably'...
                            ' the magnetic structure is wrong! For approximate'...
                            ' diagonalization try the param.hermit=false option']);
                    end
                end
                
                K2 = K*gComm*K';
                K2 = 1/2*(K2+K2');
                % Hermitian K2 will give orthogonal eigenvectors
                if param.sortMode
                    [U, D] = eigenshuffle(K2);
                else
                    [U, D] = eig(K2);
                    D = diag(D);
                end
                
                % sort eigenvalues to decreasing order this contradicts with
                % eigenshuffle
                
                % TODO
                [D, idx] = sort(D,'descend');
                U = U(:,idx);
                
                % omega dispersion
                omega(:,end+1) = D; %#ok<AGROW>
                
                % the inverse of the para-unitary transformation V
                V(:,:,ii) = inv(K)*U*diag(sqrt(gCommd.*omega(:,end))); %#ok<MINV>
            end
        end
    else
        % All the matrix calculations are according to White's paper
        % R.M. White, et al., Physical Review 139, A450?A454 (1965)
        
        %gham = 0*ham;
        %for ii = 1:nHklMEM
        %    gham(:,:,ii) = gComm*ham(:,:,ii);
        %end
        
        if param.useMex
            gham = sw_mtimesx(gComm,ham);
        else
            gham = mmat(gComm,ham);
        end
        
        [V, omega(:,hklIdxMEM)] = eigorth(gham, param.omega_tol, param.sortMode, param.useMex);
        
        for ii = 1:nHklMEM
            % multiplication with g removed to get negative and positive
            % energies as well
            M              = diag(gComm*V(:,:,ii)'*gComm*V(:,:,ii));
            V(:,:,ii)      = V(:,:,ii)*diag(sqrt(1./M));
        end
    end
    
    if param.saveV
        Vsave(:,:,hklIdxMEM) = V;
    end
    if param.saveH
        Hsave(:,:,hklIdxMEM) = ham;
    end

    % Calculates correlation functions.
    if param.useMex %&& size(V,1)>10
        ExpF = exp(-1i*sum(repmat(permute(hklExt0MEM,[1 3 2]),[1 nMagExt 1]).*repmat(RR,[1 1 nHklMEM]),1));
        ExpF = reshape(ExpF,[numel(S0) nHklMEM]).*repmat(sqrt(S0.'/2),[1 nHklMEM]);
        ExpF = repmat(ExpF,[2 1]); 
        if iscell(param.formfact) || param.formfact; 
            ExpF = ExpF .* repmat(FF(:,hklIdxMEM),[2 1]); 
        end
        z1=zed;
        if param.gtensor; 
            for i1=1:size(gtensor,3); 
                z1(:,i1)=gtensor(:,:,i1)*zed(:,i1); 
            end
        end
        z1=[z1 conj(z1)].'; 
        zExp = zeros(numel(S0)*2,1,nHklMEM,3);
        for i1=1:3; 
            zExp(:,:,:,i1) = bsxfun(@times,z1(:,i1),ExpF);
        end
        
        for i1=1:3; 
            for i2=1:3; 
                Sab(i1,i2,:,hklIdxMEM) = sw_mtimesx(V,'C',zExp(:,:,:,i1)).*conj(sw_mtimesx(V,'C',zExp(:,:,:,i2))) / prod(nExt);
            end
        end
    else
        % V right
        VExtR = repmat(permute(V  ,[4 5 1 2 3]),[3 3 1 1 1]);
        % V left: conjugate transpose of V
        VExtL = conj(permute(VExtR,[1 2 4 3 5]));
    
        % Introduces the exp(-ikR) exponential factor.
        ExpF =  exp(-1i*sum(repmat(permute(hklExt0MEM,[1 3 2]),[1 nMagExt 1]).*repmat(RR,[1 1 nHklMEM]),1));
        % Includes the sqrt(Si/2) prefactor.
        ExpF = ExpF.*repmat(sqrt(S0/2),[1 1 nHklMEM]);
    
        ExpFL =      repmat(permute(ExpF,[1 4 5 2 3]),[3 3 2*nMagExt 2]);
        % conj transpose of ExpFL
        ExpFR = conj(permute(ExpFL,[1 2 4 3 5]));
    
        zeda = repmat(permute([zed conj(zed)],[1 3 4 2]),[1 3 2*nMagExt 1 nHklMEM]);
        % conj transpose of zeda
        zedb = conj(permute(zeda,[2 1 4 3 5]));
    
        % calculate magnetic structure factor using the hklExt0 Q-values
        % since the S(Q+/-k,omega) correlation functions also belong to the
        % F(Q)^2 form factor
    
        if iscell(param.formfact) || param.formfact
            % include the form factor in the z^alpha, z^beta matrices
            zeda = zeda.*repmat(permute(FF(:,hklIdxMEM),[3 4 5 1 2]),[3 3 2*nMagExt 2 1]);
            zedb = zedb.*repmat(permute(FF(:,hklIdxMEM),[3 4 1 5 2]),[3 3 2 2*nMagExt 1]);
        end
    
        if param.gtensor
            % include the g-tensor
            zeda = mmat(repmat(permute(gtensor,[1 2 4 3]),[1 1 1 2]),zeda);
            zedb = mmat(zedb,repmat(gtensor,[1 1 2]));
        end
        % Dynamical for factor from S^alpha^beta(k) correlation function.
        % Sab(alpha,beta,iMode,iHkl), size: 3 x 3 x 2*nMagExt x nHkl.
        % Normalizes the intensity to single unit cell.
        Sab = cat(4,Sab,squeeze(sum(zeda.*ExpFL.*VExtL,4)).*squeeze(sum(zedb.*ExpFR.*VExtR,3))/prod(nExt));
    end
    
    sw_status(jj/nSlice*100,0,param.tid);
end

% If number of formula units are given per cell normalize to formula
% unit
if obj.unit.nformula > 0
    Sab = Sab/double(obj.unit.nformula);
end

sw_status(100,2,param.tid);

fprintf0(fid,'Calculation finished.\n');

if warn1 && ~param.fitmode
    warning('sw:spinwave:NonPosDefHamiltonian',['To make the Hamiltonian '...
        'positive definite, a small omega_tol value was added to its diagonal!'])
end

%fprintf0(fid,'t/c: %g %g %g %e\n',[sum(t1) sum(t2b) sum(t2) sum(abs(Sab(:)-Sabt(:)))]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% END MEMORY MANAGEMENT LOOP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if incomm
    % resize matrices due to the incommensurability (k-km,k,k+km) multiplicity
    kmIdx = repmat(sort(repmat([1 2 3],1,nHkl0/3)),1,nTwin);
    % Rodrigues' rotation formula.
    nx  = [0 -n(3) n(2); n(3) 0 -n(1); -n(2) n(1) 0];
    nxn = n'*n;
    K1 = 1/2*(eye(3) - nxn - 1i*nx);
    K2 = nxn;
    
    % keep the rotation invariant part of Sab
    %nx  = [0 -n(3) n(2);n(3) 0 -n(1);-n(2) n(1) 0];
    %nxn = n'*n;
    m1  = eye(3);
    
    % if the 2*km vector is integer, the magnetic structure is not a true
    % helix
    %tol = param.tol*2;
    %helical =  sum(abs(mod(abs(2*km)+tol,1)-tol).^2) > tol;
    
    if helical
        % integrating out the arbitrary initial phase of the helix
        Sab = 1/2*Sab - 1/2*mmat(mmat(nx,Sab),nx) + 1/2*mmat(mmat(nxn-m1,Sab),nxn) + 1/2*mmat(mmat(nxn,Sab),2*nxn-m1);
    end
    
    % Save the structure factor in the rotating frame
    if param.saveSabp
        Sabp = Sab(:,:,:,kmIdx==2);
        omegap = omega(:,kmIdx==2);
    end
    
    % dispersion
    omega = [omega(:,kmIdx==1); omega(:,kmIdx==2); omega(:,kmIdx==3)];
    % exchange matrices
    Sab   = cat(3,mmat(Sab(:,:,:,kmIdx==1),K1), mmat(Sab(:,:,:,kmIdx==2),K2), ...
        mmat(Sab(:,:,:,kmIdx==3),conj(K1)));
    
    hkl   = hkl(:,kmIdx==2);
    nHkl0 = nHkl0/3;
else
    helical = false;
end

if ~param.notwin
    % Rotate the calculated correlation function into the twin coordinate
    % system using rotC
    SabAll = cell(1,nTwin);
    for ii = 1:nTwin
        % select the ii-th twin from the Q points
        idx    = (1:nHkl0) + (ii-1)*nHkl0;
        % select correlation function of twin ii
        SabT   = Sab(:,:,:,idx);
        % size of the correlation function matrix
        sSabT  = size(SabT);
        % convert the matrix into cell of 3x3 matrices
        SabT   = reshape(SabT,3,3,[]);
        % select the rotation matrix of twin ii
        rotC   = obj.twin.rotc(:,:,ii);
        % rotate correlation function using arrayfun
        SabRot = arrayfun(@(idx)(rotC*SabT(:,:,idx)*(rotC')),1:size(SabT,3),'UniformOutput',false);
        SabRot = cat(3,SabRot{:});
        % resize back the correlation matrix
        SabAll{ii} = reshape(SabRot,sSabT);
    end
    Sab = SabAll;
    
    if nTwin == 1
        Sab = Sab{1};
    else
        omega = mat2cell(omega,size(omega,1),repmat(nHkl0,[1 nTwin]));
    end
    
end

% Creates output structure with the calculated values.
spectra.omega    = omega;
spectra.Sab      = Sab;
spectra.hkl      = hkl(:,1:nHkl0);
spectra.hklA     = hklA;
spectra.incomm   = incomm;
spectra.helical  = helical;
spectra.norm     = false;
spectra.nformula = double(obj.unit.nformula);

% Save different intermediate results.
if param.saveV
    spectra.V = Vsave;
end
if param.saveH
    spectra.H = Hsave;
end
if param.saveSabp && incomm
    spectra.Sabp = Sabp;
    spectra.omegap = omegap;
end

% save the important parameters
spectra.param.notwin    = param.notwin;
spectra.param.sortMode  = param.sortMode;
spectra.param.tol       = param.tol;
spectra.param.omega_tol = param.omega_tol;
spectra.param.hermit    = param.hermit;
spectra.dateend         = datestr(now);
spectra.title           = param.title;
spectra.gtensor         = param.gtensor;

if ~param.fitmode
    spectra.obj = copy(obj);
end

end
