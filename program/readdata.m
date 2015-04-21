function data = readdata(file)
%READDATA   Read data from a file.
%  READDATA(FILE) reads tab-delimited data from FILE and returns a struct.
%  The field names of the struct are given by the header line in FILE.
%  Columns with field names 'p1', 'p2' or 'proom' are converted from bars
%  to Pa, i.e., multiplied by 1e5; Columns with field names 'T1', 'T2' or
%  'Troom' are converted from degree Celsius to Kelvin, i.e., 273.15 is
%  added. Columns with field names 'volume' are converted from ml to m3 by
%  multiplying by 1e-6.
%
%  Example:
%
%  Suppose a file meas.tsv contains the tab-delimited text
%     Date       substance  p1   p2
%     12.3.2015  nitrogen   1.2  0.995  
%     15.3.2015  butane     1.3  1
%  then DATA = READDATA('meas.tsv') returns a 1x1 struct DATA with the
%  fields DATA.Date, DATA.substance, DATA.p1 and DATA.p2.
%  DATA.Date and DATA.substance are 2x1 cell arrays containing
%  {'12.3.2015; '15.3.2015'}, and {'nitrogen'; 'butane'}, respectively. and
%  DATA.p1 and DATA.p2 are 2x1 numeric arrays. DATA.p1 contains
%  [120000; 130000], DATA.p2 contains [99500 100000].

% Set the delimiter.
del = '\t';

fid = fopen(file);

% Get the variable names.
%		textscan cares for \r\n, ignores the \r, if present
[line, pos] = textscan(fid,'%s',1,'Delimiter','\n');
name = strsplit(line{1}{1},del);
len = size(name,2);

% Read the second line for testing whether a column is numeric or string.
line = textscan(fid,'%s',len,'Delimiter',del);
fmt(1:2*len) = '%';

% Loop over columns.
%   1. Set read format, numeric or string.
%   2. Sanitize variable names.
for i = 1:len
  %  Set read format, numeric or string.
  if any(isstrprop(line{1}{i},'alpha')) || sum(line{1}{i} == '.') > 1
    fmt(2*i) = 's';
  else
    fmt(2*i) = 'n';
  end
  %  Sanitize variable names.
  if ~isvarname(name{i})
    name{i} = name{i}(isstrprop(name{i},'alphanum'));
    if ~isvarname(name{i})
      error('Column %d header ''%s'' is not a valid matlab variable name.',...
	    i, name{i});
    end
  end
end

fseek(fid,pos,'bof');	% Seek to postition pos from beginning of file.
% d = textscan(fid,fmt,'Delimiter',del,'CommentStyle','#');
% data = cell2struct(d, name, 2)
data = cell2struct(textscan(fid,fmt,'Delimiter',del,'CommentStyle','#'),...
		   name, 2);
fclose(fid);

% Scale some fields.
convert = {{'p1', 'p2', 'proom'}, @(x) x * 1e5; ...	  bar to Pa
	   {'T1', 'T2', 'Troom'}, @(x) x + 273.15;...	  Celsius to Kelvin
	   {'volume'}, @(x) x * 1e-6};			% ml to m3

for i = 1:size(convert,1)
  for str = {convert{i,1}{isfield(data, convert{i,1})}}
    data.(str{1}) = convert{i,2}(data.(str{1}));
  end
end
