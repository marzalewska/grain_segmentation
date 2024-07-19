%glaukonit
close all; clear; clc;
img = imread('snap_002.tif');
% Maska kołowa
[rows, cols, ~] = size(img);
[X, Y] = meshgrid(1:cols, 1:rows);
centerX = cols / 2;
centerY = rows / 2;
mask = sqrt((X - centerX).^2 + (Y - centerY).^2) <= 760;

% Przycięcie obrazu do kształtu koła korzystając z maski
kolo_glauk = img;
kolo_glauk(repmat(~mask, [1, 1, size(img, 3)])) = 0; %repmat powiela macierz ~mask tak, aby miała te same wymiary co oryginalny obraz img

% Zamiana kolorów na LAB
labImg = rgb2lab(kolo_glauk);
ab = labImg(:,:,2:3);
ab = im2single(ab);

% Klasteryzacja K-means
nColors = 3; % liczba klas kolorów w obrazie
pixel_labels = imsegkmeans(ab, nColors, 'NumAttempts', 3);
segmented = cell(1, nColors);
rgb_label = repmat(pixel_labels, [1 1 3]);

for k = 1:nColors
    color = kolo_glauk;
    color(rgb_label ~= k) = 0;
    segmented{k} = color;
    subplot(1,nColors,k), imshow(segmented{k})
end

% Jako że na segmencie drugim znalazł się kolor zielony, to on od tego
% czasu będzie nas interesował
seg2 = segmented{2};
seg2_szare = rgb2gray(seg2);
seg2_bin = imbinarize(seg2_szare);

% Usunięcie małych obiektów (kaszki) oraz zamknięcie dziur
seg2_bin = bwareaopen(seg2_bin, 1000);
seg2_bin = imfill(seg2_bin, 'holes');

seg2_filtered = seg2;
%przefiltrowanie segmentu drugiego dla każdego koloru tą samą binarną
%maską, filtracją medianową oraz uzupełnieniem dziur
for col = 1:3
    seg2_filtered(:,:,col) = seg2(:,:,col) .* uint8(seg2_bin);
    seg2_filtered(:,:,col) = medfilt2(seg2_filtered(:,:,col), [5 5]);
    seg2_filtered(:,:,col) = imfill(seg2_filtered(:,:,col), 'holes');
end

%figure;
%imshow(seg2_filtered);
%title('Przefiltrowany glaukonit');
imwrite(seg2_filtered, 'seg2_filtered.png');

props_glauconite = regionprops(seg2_bin, 'BoundingBox', 'Centroid', 'Area', 'PixelIdxList');

% Wyodrębnienie i zapisanie każdego ziarna jako osobnego obrazu do
% sprawdzenia jak zadziałało regionprops
% outputDir = 'separated_grains';
% if ~exist(outputDir, 'dir')
%     mkdir(outputDir);
% end

% Nowy obraz, który nie będzie zawierał najmniejszych obiektów
combined = zeros(size(seg2_filtered), 'uint8');

for i = 1:numel(props_glauconite)
    grainMask = false(size(seg2_bin));
    grainMask(props_glauconite(i).PixelIdxList) = true;
    grain = seg2_filtered;
    for col = 1:3
        grain(:,:,col) = grain(:,:,col) .* uint8(grainMask);
    end
    %sprawdzenie czy pole nie jest za małe
    if props_glauconite(i).Area < 1500
        continue;
    end

    combined = combined + grain;

    % Zapisanie każdego ziarna dla sprawdzenia czy wykonało się poprawnie
    %imwrite(grain, fullfile(outputDir, sprintf('grain_%02d.png', i)));
end

figure;
imshow(combined);
title('Połączone ziarna z wyłączeniem najmniejszych');
imwrite(combined, 'combined_grains_glauconite.png');
%%
close all;
%ustawienie ostatecznej maski dla glaukonitu do dalszego użycia
bin_glaukonit_1n = combined(:,:,1)>0 & combined(:,:,2)>0 &combined(:,:,3)>0;
imshow(bin_glaukonit_1n);
obrot_0 = imread('obrot_0.tif');
imshow(obrot_0)

%wycięcie koła dla obrazu przy dwóch polaryzatorach
kolo_0 = obrot_0;
kolo_0(repmat(~mask, [1, 1, size(obrot_0, 3)])) = 0;
imshow(kolo_0)

overlay_glaukonit = kolo_0;
for col = 1:3
    overlay_glaukonit(:,:,col) = overlay_glaukonit(:,:,col) .* uint8(bin_glaukonit_1n);
end

%obliczenie pola
pole_glaukonit = bwarea(bin_glaukonit_1n) %pole w pikselach
pole_glaukonit = pole_glaukonit*(100/175)^2 %pole w mikro m^2
%1808-1983=175
%175px-100mikro
%1px-100/175
figure;
imshow(overlay_glaukonit);
title('Nałożenie maski glaukonitu na obraz z dwoma polaryzatorami');
imwrite(overlay_glaukonit, 'overlay_glaukonit.png');
%%
%kwarc
close all;

n_obrazow = 330 / 30 + 1;
%zmienne do subplotów
numCols = ceil(sqrt(n_obrazow));
numRows = ceil(n_obrazow / numCols);

%wczytanie obrazów
for i = 0:30:330
    filename = sprintf('obrot_%d.tif', i);
    img = imread(filename);
    
    varName = sprintf('obr%d', i);
    assignin('base', varName, img);
    
    subplot(numRows, numCols, i/30 + 1);
    %imshow(img);
    title(sprintf('Obrot %d', i));
end

subplot(numRows, numCols,1), imshow(obr0);
% obrót obrazów aby zgadzały się z położeniem w punkcie 0
for i = 30:30:330
    varName = sprintf('obr%d', i);
    img = evalin('base', varName);
    
    rotated = imrotate(img, i, 'bilinear', 'crop');
    
    rotatedName = sprintf('rot_obr%d', i);
    assignin('base', rotatedName, rotated);
    
    subplot(numRows, numCols, i/30 + 1);
    imshow(rotated);
    title(sprintf('Obrót o kąt %d st.', i));
end

%wycięcie maski koła
figure
for i = 30:30:330
    varName = sprintf('rot_obr%d', i);
    img = evalin('base', varName);
   
    mask=mask|bin_glaukonit_1n;
    cropped = img;
    cropped(repmat(~mask, [1, 1, size(img, 3)])) = 0;
    croppedName = sprintf('cropped_rot_obr%d', i);
    assignin('base', croppedName, cropped);
    
    subplot(numRows, numCols, i/30 + 1);
    imshow(cropped);
    title(sprintf('Obrot %d', i));
end
cropped_rot_obr0=obr0;
cropped_rot_obr0(repmat(~mask, [1, 1, size(obr0, 3)])) = 0;
subplot(numRows, numCols, 1);
imshow(cropped_rot_obr0);
title('Obrot 0');
%%
close all;
figure
subplot(221)
imshow(cropped_rot_obr0)
subplot(222)
imshow(cropped_rot_obr30)
subplot(223)
imshow(cropped_rot_obr60)
subplot(224)
imshow(cropped_rot_obr90)
%saveas(gcf,'rotacje_i_kółka.png')

%binaryzacja w celu znalezienia kwarcu dla kąta 0 stopni
%figure, subplot(121),imshow(cropped_rot_obr0)
bin_0=cropped_rot_obr0(:,:,1)>130 & cropped_rot_obr0(:,:,2)>130 & cropped_rot_obr0(:,:,3)>130;
% subplot(122),imshow(bin_0)
% figure, subplot(121),imshow(cropped_rot_obr30)
%binaryzacja w celu znalezienia kwarcu dla kąta 30 stopni
bin_30=cropped_rot_obr30(:,:,1)>130 & cropped_rot_obr30(:,:,2)>130 & cropped_rot_obr30(:,:,3)>130;
% subplot(122),imshow(bin_30)
% figure, subplot(121),imshow(cropped_rot_obr60)
%binaryzacja w celu znalezienia kwarcu dla kąta 60 stopni
bin_60=cropped_rot_obr60(:,:,1)>130 & cropped_rot_obr60(:,:,2)>130 & cropped_rot_obr60(:,:,3)>130;
%subplot(122),imshow(bin_60)

close all;
figure,
subplot(231), imshow(cropped_rot_obr0)
subplot(234), imshow(bin_0)
subplot(232), imshow(cropped_rot_obr30)
subplot(235), imshow(bin_30)
subplot(233), imshow(cropped_rot_obr60)
subplot(236), imshow(bin_60)

%filtracja dla położenia 0
bin_0_filtred = bin_0;
bin_0_filtred = bwareaopen(bin_0_filtred, 1000);
bin_0_filtred = imfill(bin_0_filtred, 'holes');
%figure,
%imshow(bin_0_filtred)

props_bin_0 = regionprops(bin_0_filtred, 'BoundingBox', 'Centroid', 'Area', 'PixelIdxList');

%stworzenie katalogu do przechowywania oddzielnych ziaren dla kąta 0
% outputDir = 'separated_grains_bin_0';
% if ~exist(outputDir, 'dir')
%     mkdir(outputDir);
% end

%stworzenie obrazu ze wszystkimi większymi ziarnami 
combined_bin_0 = zeros(size(bin_0_filtred), 'uint8');
for i = 1:numel(props_bin_0)
    grainMask = false(size(bin_0_filtred));
    grainMask(props_bin_0(i).PixelIdxList) = true;
    
    grain = zeros(size(cropped_rot_obr0), 'like', cropped_rot_obr0);
    for col = 1:3
        grain(:,:,col) = cropped_rot_obr0(:,:,col) .* uint8(grainMask);
    end
    if props_bin_0(i).Area < 1500
        continue;
    end
    combined_bin_0 = combined_bin_0 + grain;
    % Zapisanie obrazu z pojedynczym ziarnem
    %imwrite(grain, fullfile(outputDir, sprintf('grain_%02d.png', i)));
end
figure,
imshow(combined_bin_0)
%%
close all;
%filtracja dla obrazu z obrotem o 30 stopni
bin_30_filtred = bin_30;
bin_30_filtred = bwareaopen(bin_30_filtred, 1000);
bin_30_filtred = imfill(bin_30_filtred, 'holes');
%figure; subplot(121), imshow(bin_30)
%subplot(122),imshow(bin_30_filtred)

props_bin_30 = regionprops(bin_30_filtred, 'BoundingBox', 'Centroid', 'Area', 'PixelIdxList');

% outputDir = 'separated_grains_bin_30';
% if ~exist(outputDir, 'dir')
%     mkdir(outputDir);
% end

combined_bin_30 = zeros(size(bin_30_filtred), 'uint8');

for i = 1:numel(props_bin_30)
    grainMask = false(size(bin_30_filtred));
    grainMask(props_bin_30(i).PixelIdxList) = true;
    grain = zeros(size(cropped_rot_obr30), 'like', cropped_rot_obr30);
    for col = 1:3
        grain(:,:,col) = cropped_rot_obr30(:,:,col) .* uint8(grainMask);
    end
    if props_bin_30(i).Area < 500
        continue;
    end
    combined_bin_30 = combined_bin_30 + grain;
    % Zapisanie obrazu z pojedynczym ziarnem
    %imwrite(grain, fullfile(outputDir, sprintf('grain_%02d.png', i)));
end
figure,
imshow(combined_bin_30)
%%
close all;
%filtracja obrazów dla obrotu o 60 stopni
bin_60_filtred=bin_60;
bin_60_filtred = bwareaopen(bin_60_filtred, 1000);
bin_60_filtred = imfill(bin_60_filtred, 'holes');
% figure; subplot(121), imshow(bin_60)
% subplot(122),imshow(bin_60_filtred)

props_bin_60 = regionprops(bin_60_filtred, 'BoundingBox', 'Centroid', 'Area', 'PixelIdxList');

% outputDir = 'separated_grains_bin_60';
% if ~exist(outputDir, 'dir')
%     mkdir(outputDir);
% end

combined_bin_60 = zeros(size(bin_60_filtred), 'uint8');
for i = 1:numel(props_bin_60)
    grainMask = false(size(bin_60_filtred));
    grainMask(props_bin_60(i).PixelIdxList) = true;
    grain = zeros(size(cropped_rot_obr60), 'like', cropped_rot_obr60);
    for col = 1:3
        grain(:,:,col) = cropped_rot_obr60(:,:,col) .* uint8(grainMask);
    end
    if props_bin_60(i).Area < 2000
        continue;
    end
    combined_bin_60 = combined_bin_60 + grain;
    % Zapisanie obrazu z pojedynczym ziarnem
    %imwrite(grain, fullfile(outputDir, sprintf('grain_%02d.png', i)));
end
figure,
imshow(combined_bin_60)
%%
close all;
figure,
subplot(231), imshow(cropped_rot_obr0)
subplot(234), imshow(combined_bin_0)
subplot(232), imshow(cropped_rot_obr30)
subplot(235), imshow(combined_bin_30)
subplot(233), imshow(cropped_rot_obr60)
subplot(236), imshow(combined_bin_60)
saveas(gcf,'Znaleziony_kwarc.png')

% Przesunięcie bin_30 i bin_60 o kilka pikseli do góry
bin_30_up = imtranslate(combined_bin_30, [0, -10]);
bin_60_up = imtranslate(combined_bin_60, [0, -15]);

figure,
%połączenie wszystkich binaryzacji w jedną ostateczną
ultimate_bin = combined_bin_0 + bin_30_up + bin_60_up;
imshow(ultimate_bin)
ultimate_bin=ultimate_bin(:,:,1)>0 & ultimate_bin(:,:,2)>0 & ultimate_bin(:,:,3)>0; 
ultimate_bin = ultimate_bin & ~bin_glaukonit_1n;
se = strel('disk', 3);
ultimate_bin = imopen(ultimate_bin, se);
ultimate_bin = imclose(ultimate_bin, se);
ultimate_bin = imfill(ultimate_bin, 'holes');

imshow(ultimate_bin)

%obliczenie pola dla kwarcu
pole_kwarc = bwarea(ultimate_bin) %pole w pikselach
pole_kwarc = pole_kwarc*(100/175)^2
%%
%kalcyt
close all;

% Wyświetlenie obrazów wyjściowych z poprzednich obliczeń
figure,
subplot(221), imshow(cropped_rot_obr0)
subplot(222), imshow(ultimate_bin)
subplot(223), imshow(bin_glaukonit_1n)

% Połączenie bin_glaukonit_1n i ultimate_bin w jedną maskę
combined_mask = bin_glaukonit_1n | ultimate_bin;
subplot(224), imshow(combined_mask)

% Usunięcie elementów z obrazu korzystając combined_mask
nowy_obraz_wejsciowy = cropped_rot_obr0;
for col = 1:3
    nowy_obraz_wejsciowy(:,:,col) = nowy_obraz_wejsciowy(:,:,col) .* uint8(~combined_mask);
end

% Binaryzacja dla kolorów żółtego, pomarańczowego
bin_kalcyt = nowy_obraz_wejsciowy(:,:,1) > 80 & nowy_obraz_wejsciowy(:,:,1) < 200 & ...
             nowy_obraz_wejsciowy(:,:,2) > 50 & nowy_obraz_wejsciowy(:,:,2) < 180 & ...
             nowy_obraz_wejsciowy(:,:,3) > 50 & nowy_obraz_wejsciowy(:,:,3) < 80;

figure;
imshow(bin_kalcyt);
title('Binarna maska kalcytu bez filtracji');

% Wypełnianie dziur w masce kalcytu
kalcyt_filtred= imfill(bin_kalcyt, 'holes');
se = strel('disk', 7);
kalcyt_filtred = imclose(kalcyt_filtred, se);
kalcyt_filtred = imfill(kalcyt_filtred, 'holes');

% Upewnienie się że po operacjach żaden z pikseli kwarcu ani glaukonitu nie
% będzie też kalcytem
ultimate_kalcyt = nowy_obraz_wejsciowy;
for col = 1:3
    ultimate_kalcyt(:,:,col) = ultimate_kalcyt(:,:,col) .* uint8(~combined_mask);
end

props_kalcyt = regionprops(kalcyt_filtred, 'BoundingBox', 'Centroid', 'Area', 'PixelIdxList');

% outputDir = 'kalcyt_grains';
% if ~exist(outputDir, 'dir')
%     mkdir(outputDir);
% end

% Initialize combined image
combined_kalcyt = zeros(size(kalcyt_filtred), 'uint8');
for i = 1:numel(props_kalcyt)
    if props_kalcyt(i).Area < 400
        continue; 
    end
    
    kalcytMask = false(size(kalcyt_filtred));
    kalcytMask(props_kalcyt(i).PixelIdxList) = true;
    kalcyt = ultimate_kalcyt;
    for ch = 1:3
        kalcyt(:,:,ch) = kalcyt(:,:,ch) .* uint8(kalcytMask);
    end
    combined_kalcyt = combined_kalcyt + kalcyt;
    
    %imwrite(kalcyt, fullfile(outputDir, sprintf('kalcyt_%02d.png', i)));
end

figure;
imshow(combined_kalcyt);
title('Kalcyt z wyłączeniem małych obiektów');
imwrite(combined_kalcyt, 'combined_kalcyt.png');
a=combined_kalcyt(:,:,1)>0& combined_kalcyt(:,:,2)>0 &combined_kalcyt(:,:,3)>0; %maska binarna kalcytu
imshow(combined_kalcyt)
% Obliczenie pola kalcytu
pole_kalcyt = bwarea(a) % pole w pikselach
pole_kalcyt = pole_kalcyt * (100/175)^2 % pole w mm^2

%%
close all;

%ustawienie od nowa maski koła dla obrazu wynikowego
[rows, cols, ~] = size(cropped_rot_obr0);
[X, Y] = meshgrid(1:cols, 1:rows);
centerX = cols / 2;
centerY = rows / 2;
circle_mask = sqrt((X - centerX).^2 + (Y - centerY).^2) <= 760;
cropped_rot_obr0(~repmat(circle_mask, [1, 1, 3])) = 0;

% Kolory dla masek
color_ultimate_bin = [255, 0, 0];  % Czerwony
color_bin_glaukonit = [0, 255, 0];  % Zielony
color_a = [0, 0, 255];  % Niebieski
color_other = [255, 255, 0];  % Żółty

% Tworzenie kolorowych masek
color_mask_ultimate_bin = cat(3, ultimate_bin * color_ultimate_bin(1), ...
                                 ultimate_bin * color_ultimate_bin(2), ...
                                 ultimate_bin * color_ultimate_bin(3));

color_mask_bin_glaukonit_1n = cat(3, bin_glaukonit_1n * color_bin_glaukonit(1), ...
                                    bin_glaukonit_1n * color_bin_glaukonit(2), ...
                                    bin_glaukonit_1n * color_bin_glaukonit(3));

color_mask_a = cat(3, a * color_a(1), ...
                      a * color_a(2), ...
                      a * color_a(3));

% Maska dla innych
combined_mask = ultimate_bin | bin_glaukonit_1n | a;
mask_other = ~combined_mask & circle_mask;

color_mask_other = cat(3, mask_other * color_other(1), ...
                          mask_other * color_other(2), ...
                          mask_other * color_other(3));

% Nałożenie kolorowych masek na oryginalny obraz
combined_image = im2double(cropped_rot_obr0);

% Nałożenie na siebie kolorowych masek za pomocą funckji
combined_image = imoverlay(combined_image, mask_other, color_other);
combined_image = imoverlay(combined_image, ultimate_bin & circle_mask, color_ultimate_bin);
combined_image = imoverlay(combined_image, bin_glaukonit_1n & circle_mask, color_bin_glaukonit);
combined_image = imoverlay(combined_image, a & circle_mask, color_a);

figure;
imshow(combined_image);
title('Nałożone kolorowe maski na oryginalny obraz');
imwrite(combined_image, 'Zlaczone_maksi.png');


% legenda
hold on;
text(20, 50, 'Kwarc', 'Color', [1 0 0], 'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', 'white');
text(20, 130, 'Glaukonit', 'Color', [0 1 0], 'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', 'white');
text(20, 210, 'Kalcyt', 'Color', [0 0 1], 'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', 'white');
text(20, 290, 'Inne', 'Color', [1 1 0], 'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', 'white');
hold off;

% Funkcja imoverlay do nakładania kolorowych masek
function out = imoverlay(in, mask, color)
    mask = logical(mask);
    out = in;
    for i = 1:3
        channel = out(:,:,i);
        channel(mask) = color(i) / 255;
        out(:,:,i) = channel;
    end
end

