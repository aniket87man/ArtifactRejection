function dataDC = removeDC(data, blpos)
    dc = mean(data(:, blpos), 2);
    dataDC = data - dc;
end