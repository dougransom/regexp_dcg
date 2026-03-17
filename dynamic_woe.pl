:-dynamic(debug_mode/1).


debug_mode(off).
set_debug(on)  :- retractall(debug_mode(_)), assertz(debug_mode(on)).
set_debug(off) :- retractall(debug_mode(_)), assertz(debug_mode(off)).
