function moments = magtable(obj)
% creates tabulated list of all magnetic moments stored in obj
%
% moments = MAGTABLE(obj)
%
% The function lists the APPROXIMATED moment directions (using the rotating
% coordinate system notation) in the magnetic supercell, whose size is
% defined by the obj.mag_str.nExt field. The positions of the magnetic
% atoms are in lattice units.
%
% Input:
%
% obj           spinw class object.
%
% Output:
%
% 'moments' is struct type data that contains the following fields:
%   M           Matrix, where every column defines a magnetic moment,
%               dimensions are [3 nMagExt].
%   e1,e2,e3    Unit vectors of the coordinate system used for the spin
%               wave calculation, the i-th column contains a normalized
%               vector for the i-th moment. e3 is parallel to the magnetic
%               moment, e1 and e2 span a right handed orthogonal coordinate
%               system.
%   R           Matrix, where every column defines the position of the
%               magnetic atom in lattice units.
%   atom        Pointer to the magnetic atom in the subfields of
%               spinw.unit_cell.
%
% See also SPINW.GENMAGSTR.
%

M0 = obj.magstr.S;
S0 = sqrt(sum(M0.^2,1));
nMagExt = size(M0,2);

% Local (e1,e2,e3) coordinate system fixed to the moments.
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

moments.M = M0;

% local coordinate system
moments.e1 = e1;
moments.e2 = e2;
moments.e3 = e3;

mAtom = obj.matom;
nExt  = obj.magstr.N_ext;

% Create mAtom.Sext matrix.
mAtom    = sw_extendlattice(nExt, mAtom);

if isempty(moments.M)
    moments.R = zeros(3,0);
    moments.atom = zeros(1,1);
else
    % Positions in l.u.
    moments.R = bsxfun(@times,mAtom.RRext,nExt');
    
    % atom idx values
    moments.atom = repmat(mAtom.idx,[1 prod(nExt)]);
end

if ~verLessThan('matlab','R2013b')
    % TODO add table
end

end