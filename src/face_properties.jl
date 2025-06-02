################################################################
#                      Face properties
################################################################

face_center(vs::StaticVector{3, <:StaticVector{3}}) = face_center(vs...)
face_center(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = (v1 + v2 + v3) / 3

face_normal(vs::StaticVector{3, <:StaticVector{3}}) = face_normal(vs...)
face_normal(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = normalize((v2 - v1) × (v3 - v2))

face_area(vs::StaticVector{3, <:StaticVector{3}}) = face_area(vs...)
face_area(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = norm((v2 - v1) × (v3 - v2)) / 2
