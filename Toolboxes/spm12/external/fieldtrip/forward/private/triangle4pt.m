function vol = triangle4pt(vol)

% FORMAT vol = triangle4pt(vol)
%
% Takes the volume model and estimates the 4th point of each triangle of
% each mesh.
%
% In each vol.bnd sub-structure, a field '.pnt4' is added. The '.pnt4'
% field is a Ntri*3 matrix, with the coordinates of a point for each
% triangle in the meshed surface.
%
% Explanations:
% The point is that for some BEM, specifically 'solid angle', calculation
% it is necessary to estimate the local curvature of the true surface which
% is approximated by the flat triangle. One way to proceed is to use
% "close by" vertices to estimate the overall area's curvature.
% A more elegant(?) way uses a 4th point for each triangle: the "centroid"
% of the triangle is simply pusehd away from the triangle surface to fix
% the local surface curvature (assuming the surface is smooth enough).
% This 4th point is thus hovering above/under the triangle and can be used
% to fit a sphere on the triangle in a realistic way.
%
% Method:
% - The 4th point can/could be defined at the tessalation stage, based on
%   the anatomical images directly.
% - With any model, the curvature can be estimated/approximated by looking
%   at the vertices around the triangle considered and fit a sphere on
%   those few vertices, assuming the surface is smooth enough
% The latter option is the one followed here.
% The extra-vertices considered here are those 3 which are linked to the
% triangle by 2 edges.
%__________________________________________________________________________
%
% written by Christophe Phillips, 2009/01/19
% Cyclotron Research Centre, University of li?ge, belgium
%
% $Id: triangle4pt.m 8446 2013-09-05 17:48:55Z vlalit $

Ns = length(vol.bnd);
for ii=1:Ns % treat each mesh one at a time
  tri = vol.bnd(ii).tri;
  pnt = vol.bnd(ii).pnt;
  Nt = size(tri,1);
  pnt4 = zeros(Nt,3);
  for jj=1:Nt % treat each triangle on a t a time
    lt1 = find(tri(:,1)==tri(jj,1) | tri(:,2)==tri(jj,1) | ...
      tri(:,3)==tri(jj,1));
    lt2 = find(tri(:,1)==tri(jj,2) | tri(:,2)==tri(jj,2) | ...
      tri(:,3)==tri(jj,2));
    lt3 = find(tri(:,1)==tri(jj,3) | tri(:,2)==tri(jj,3) | ...
      tri(:,3)==tri(jj,3));
    lt = [intersect(lt1,lt2); intersect(lt2,lt3); intersect(lt3,lt1)];
    lt(lt==jj) = [];
    % list of 3 directly surrounding triangles
    lv = tri(lt,:);
    lv = setxor(lv(:)',tri(jj,:));
    % list of 3 voxels connected by 2 edges to the jj_th triangle.
    sph_pnt = pnt([tri(jj,:) lv],:);
    [center,radius] = fitsphere(sph_pnt);
    % best fitting sphere radius & centre, for the 6 points chosen
    pnt_c = sum(pnt(tri(jj,:),:))/3;
    % centroid of the triangle treated
    if isfinite(radius)
        tmp = pnt_c-center;
        vd = tmp/norm(tmp);
        % unit vector from sphere center in direction of middle triangle
        pnt4(jj,:) = center+vd*radius ;
        % projection of the centroid, at 'radius' from the center
    else
        % radius at infinite, i.e. flat surface
        pnt4(jj,:) = pnt_c;
    end
  end
  vol.bnd(ii).pnt4 = pnt4;
end

return

% figure, plot3(pnt(:,1),pnt(:,2),pnt(:,3),'.')
% axis equal, hold on
% plot3(pnt(tri(jj,:),1),pnt(tri(jj,:),2),pnt(tri(jj,:),3),'*')
% plot3(pnt(lv,1),pnt(lv,2),pnt(lv,3),'o')
% plot3(pnt4(jj,1),pnt4(jj,2),pnt4(jj,3),'rs')
