function rp_max=JQ_estimate_maxRP(rp_file)
    rp=load(rp_file);
    rp_max=max(abs(rp),[],1);
    rp_max(4:6)=rad2deg(rp_max(4:6));
    rp_max=max(rp_max);
end